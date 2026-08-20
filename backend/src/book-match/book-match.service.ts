import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BOOK_GENRES } from '../common/constants/book-genres';
import {
  BOOK_MATCH_DEFAULT_POPULARITY,
  DISCOVERY_BOOST_SWIPES,
  NEGATIVE_GENRE_THRESHOLD,
  ONBOARDING_SWIPES_TARGET,
  RECALIBRATION_COOLDOWN_DAYS,
  RECALIBRATION_FACTOR,
  aggregateScore,
  compositeBookScore,
  discoveryCountFor,
  eraForYear,
  weightedSample,
  yearRangeForEra,
  type BookMatchAction,
  type ScoreDimension,
  type ScoredSwipe,
  type UserScoreMaps,
} from './book-match.scoring';

/// Câte cărți încărcăm ca bazin de candidați pentru un batch.
const CANDIDATE_POOL_LIMIT = 1000;

/// Sub acest număr de rânduri în `books`, eșantionarea TABLESAMPLE (mai jos)
/// riscă să întoarcă prea puține/zero rânduri (e pe blocuri fizice, nu exactă
/// la tabele mici) - sub prag, luăm pur și simplu tot catalogul, ca înainte
/// de importul masiv (vezi CATALOG_SIZE_THRESHOLD_FOR_SAMPLING mai jos).
const CATALOG_SIZE_THRESHOLD_FOR_SAMPLING = CANDIDATE_POOL_LIMIT * 20;

/// Câte titluri per gen intră în pool-ul de cold start.
const COLD_START_PER_GENRE = 4;

/// Cota din batch-ul de cold start rezervată genurilor alese de user la
/// onboarding (pasul 5, Book Match) - restul sunt wildcard-uri din genuri
/// conexe, ca să nu se simtă recomandările ca fiind complet random.
const COLD_START_FAVORITE_RATIO = 0.8;

/// Câte genuri „de top" alimentează cardurile de profil.
const TOP_GENRES_FOR_PROFILE = 3;

/// Titluri populare, cross-gen, folosite ca pool de cold start atunci când
/// userul nu a selectat niciun gen favorit la onboarding - fără el, primele
/// carduri de Book Match ar fi complet random.
const COLD_START_FALLBACK_TITLES: readonly string[] = [
  '1984',
  'Marele Gatsby',
  'The Great Gatsby',
  'Mândrie și prejudecată',
  'Crimă și pedeapsă',
  'Un veac de singurătate',
  'One Hundred Years of Solitude',
  'Hoțul de cărți',
  'The Book Thief',
  'Alchimistul',
  'Să ucizi o pasăre cântătoare',
  'To Kill a Mockingbird',
  'Micul prinț',
  'The Little Prince',
  'Portretul lui Dorian Gray',
  'The Picture of Dorian Gray',
  'Harry Potter și Piatra Filosofală',
  'Stăpânul Inelelor: Frăția Inelului',
  'Hobbitul',
  'Urzeala tronurilor',
  'Cronicile din Narnia: Leul, vrăjitoarea și dulapul',
  'Numele vântului',
  'Mistborn: Ultimul Imperiu',
  'Circe',
  'O curte de spini și trandafiri',
  'Umbra vântului',
  'The Shadow of the Wind',
  'Dune',
  'Fundația',
  'Neuromantul',
  'Jocul lui Ender',
  'Fahrenheit 451',
  'Marțianul',
  'Proiectul Hail Mary',
  'Ready Player One',
  'Problema celor trei corpuri',
  'Mașina timpului',
  'Povestea noastră',
  'Înainte să te cunosc',
  'It Ends with Us',
  'It Starts with Us',
  'The Love Hypothesis',
  'Oameni normali',
  'Me Before You',
  'The Fault in Our Stars',
  'Beach Read',
  'Book Lovers',
  'Fata din tren',
  'Fata dispărută',
  'Pacienta tăcută',
  'The Silent Patient',
  'Și apoi n-a mai rămas niciunul',
  'Crima din Orient Express',
  'Codul lui Da Vinci',
  'Îngeri și demoni',
  'Shutter Island',
  'În pădure',
  'Atomic Habits',
  'Thinking, Fast and Slow',
  'Omul în căutarea sensului vieții',
  'Puterea prezentului',
  'The 7 Habits of Highly Effective People',
  'Deep Work',
  'The Psychology of Money',
  'Sapiens',
  'Factfulness',
  'Quiet',
  'Educated',
  'Becoming',
  'Steve Jobs',
  'Leonardo da Vinci',
  'Alexander Hamilton',
  'Homo Deus',
  'Prizonierul lui Stalin și Hitler',
  'Noaptea',
  'Jurnalul Annei Frank',
  'Into the Wild',
  'The Hunger Games',
  'Divergent',
  'The Maze Runner',
  "The Handmaid's Tale",
  'Never Let Me Go',
  'The Road',
  'Life of Pi',
  'The Kite Runner',
  'A Thousand Splendid Suns',
  'The Midnight Library',
  'The Seven Husbands of Evelyn Hugo',
  'Daisy Jones & The Six',
  'Where the Crawdads Sing',
  'The Song of Achilles',
  'Fourth Wing',
  'Iron Flame',
  'Shadow and Bone',
  'Six of Crows',
  'The Cruel Prince',
  'American Gods',
  'Good Omens',
  'Numele trandafirului',
  'The Catcher in the Rye',
  'One Hundred Years of Solitude',
];

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/// Cartea așa cum o vede algoritmul (și, îmbogățită, frontend-ul).
const CARD_SELECT = {
  id: true,
  title: true,
  author: true,
  coverUrl: true,
  genre: true,
  publishedYear: true,
  description: true,
  popularityScore: true,
} satisfies Prisma.BookSelect;

type CandidateBook = Prisma.BookGetPayload<{ select: typeof CARD_SELECT }>;

export interface BookMatchCard {
  bookId: string;
  title: string;
  author: string | null;
  coverUrl: string | null;
  genre: string | null;
  publishedYear: number | null;
  description: string | null;
  isDiscovery: boolean;
}

/**
 * Book Match - ecranul de swipe: o carte pe rând, Da / Nu / Skip.
 *
 * Două lucruri se întâmplă la fiecare swipe: se scrie un rând în `book_swipes`
 * (log append-only, sursa de adevăr) și se recalculează scorurile pentru cele
 * trei valori atinse de acea carte (genul ei, autorul ei, epoca ei). Recalculul
 * citește tot istoricul userului pentru acea valoare și aplică decăderea în
 * timp - deci rezultatul nu depinde de când rulează, ceea ce înseamnă că nu ne
 * trebuie niciun cron: e identic cu ce ar produce un job periodic.
 */
@Injectable()
export class BookMatchService {
  constructor(private prisma: PrismaService) {}

  // -------------------------------------------------------------------------
  // Coada
  // -------------------------------------------------------------------------

  /**
   * Următorul batch de cărți pentru sesiunea dată.
   *
   * Bazinul de candidați (max CANDIDATE_POOL_LIMIT) se încarcă în memorie și
   * se filtrează/eșantionează în Node - filtrarea pe genuri/scoruri rămâne
   * neschimbată. Ce s-a schimbat e SURSA candidaților: la catalog mic
   * (findMany simplu, fără orderBy) primele N rânduri întoarse de Postgres nu
   * sunt garantat diverse ca gen, dar la sute de titluri diferența nu se simte.
   * După importul din Open Library (peste 3.6M cărți), un `findMany` simplu ar
   * întoarce practic mereu aceleași rânduri (ordine de scanare arbitrară, dar
   * stabilă), iar `ORDER BY RANDOM()` pe toată tabela a măsurat 5.2s - inacceptabil
   * per request. `TABLESAMPLE SYSTEM` eșantionează pe blocuri fizice, nu rând cu
   * rând - sub 30ms măsurat pe 3.68M rânduri. E aproximativ (nu perfect uniform),
   * dar suficient pentru un bazin de candidați care oricum se re-eșantionează în
   * Node. Vezi `sampleCandidates` pentru pragul sub care sărim peste TABLESAMPLE.
   */
  async getQueue(
    userId: string,
    sessionId: string,
    size = 20,
  ): Promise<{ sessionId: string; cards: BookMatchCard[] }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        onboardingSwipesCount: true,
        discoveryBoostSwipesRemaining: true,
        favoriteGenres: true,
      },
    });
    if (!user) throw new NotFoundException('Utilizatorul nu a fost găsit');

    const excluded = await this.excludedBookIds(userId, sessionId);
    const candidates = await this.sampleCandidates([...excluded.all]);
    if (candidates.length === 0) {
      return { sessionId, cards: [] };
    }

    if (user.onboardingSwipesCount < ONBOARDING_SWIPES_TARGET) {
      return {
        sessionId,
        cards: await this.coldStartBatch(
          candidates,
          size,
          user.favoriteGenres,
          [...excluded.all],
        ),
      };
    }

    const scores = await this.loadScores(userId);
    const boosted = user.discoveryBoostSwipesRemaining > 0;
    return {
      sessionId,
      cards: this.personalizedBatch(
        candidates,
        scores,
        size,
        boosted,
        excluded.previouslySwiped,
      ),
    };
  }

  /**
   * Bazinul de candidați pentru o coadă - vezi comentariul de la `getQueue`
   * pentru de ce nu mai e un simplu `findMany`. Sub pragul de mărime, se
   * comportă identic cu vechea implementare (catalog mic => îl luăm tot);
   * peste prag, eșantionează fizic (TABLESAMPLE) în loc să sorteze random
   * întreaga tabelă.
   */
  private async sampleCandidates(excludedIds: string[]): Promise<CandidateBook[]> {
    // Estimare rapidă (din statisticile autovacuum, nu un COUNT(*) real - la
    // fel de scump ca interogarea pe care vrem s-o evităm). Poate fi 0 imediat
    // după un bulk-insert nean­alizat încă; fallback-ul de mai jos (findMany)
    // e oricum corect în acel caz, doar nu beneficiază de viteza TABLESAMPLE.
    const [{ estimate }] = await this.prisma.$queryRaw<{ estimate: number }[]>`
      SELECT reltuples::bigint AS estimate FROM pg_class WHERE relname = 'books'
    `;
    const approxTotal = Number(estimate) || 0;

    // Fără copertă, cardul de swipe arată doar un placeholder - o experiență
    // proastă la un ecran gândit tocmai să arate cărți atractiv. Excludem
    // cărțile fără `coverUrl` din pool-ul candidat, nu doar din selecție.
    if (approxTotal <= CATALOG_SIZE_THRESHOLD_FOR_SAMPLING) {
      // Neschimbat față de implementarea dinainte de import (`notIn: []` e
      // un filtru Prisma valid, echivalent cu "fără restricție").
      return this.prisma.book.findMany({
        where: { id: { notIn: excludedIds }, coverUrl: { not: null } },
        select: CARD_SELECT,
        take: CANDIDATE_POOL_LIMIT,
      });
    }

    // Marjă x3 față de target: TABLESAMPLE SYSTEM aproximează pe blocuri (nu
    // exact pe rânduri), iar rândurile excluse (inclusiv cele fără copertă)
    // mai reduc din câte rămân utile.
    const samplePercent = Math.min(100, ((CANDIDATE_POOL_LIMIT * 3) / approxTotal) * 100);

    return excludedIds.length > 0
      ? this.prisma.$queryRaw<CandidateBook[]>`
          SELECT id, title, author, "coverUrl", genre, "publishedYear", description, "popularityScore"
          FROM books TABLESAMPLE SYSTEM (${samplePercent})
          WHERE id NOT IN (${Prisma.join(excludedIds)})
            AND "coverUrl" IS NOT NULL
          ORDER BY RANDOM()
          LIMIT ${CANDIDATE_POOL_LIMIT}
        `
      : this.prisma.$queryRaw<CandidateBook[]>`
          SELECT id, title, author, "coverUrl", genre, "publishedYear", description, "popularityScore"
          FROM books TABLESAMPLE SYSTEM (${samplePercent})
          WHERE "coverUrl" IS NOT NULL
          ORDER BY RANDOM()
          LIMIT ${CANDIDATE_POOL_LIMIT}
        `;
  }

  /**
   * Cărțile care nu au voie în coadă:
   *  - `all` - orice carte atinsă în sesiunea curentă (regulă dură), plus
   *    orice „Yes" din trecut și orice titlu deja pe wishlist (un „da" duce
   *    cartea pe wishlist, deci n-are sens s-o mai întrebăm), plus cărțile pe
   *    care userul le are deja listate (sunt ale lui).
   *  - `previouslySwiped` - „Nu"/„Skip" din sesiuni anterioare: au voie să
   *    revină, dar cu greutate ajustată de scorurile curente.
   */
  private async excludedBookIds(userId: string, sessionId: string) {
    const [swipes, wishlist, owned] = await Promise.all([
      this.prisma.bookSwipe.findMany({
        where: { userId },
        select: { bookId: true, action: true, sessionId: true },
      }),
      this.prisma.wishlistItem.findMany({
        where: { userId },
        select: { bookId: true },
      }),
      this.prisma.userBook.findMany({
        where: { userId, deletedAt: null },
        select: { bookId: true },
      }),
    ]);

    const all = new Set<string>();
    const previouslySwiped = new Set<string>();
    for (const swipe of swipes) {
      if (swipe.sessionId === sessionId || swipe.action === 'YES') {
        all.add(swipe.bookId);
      } else {
        previouslySwiped.add(swipe.bookId);
      }
    }
    for (const item of wishlist) all.add(item.bookId);
    for (const item of owned) all.add(item.bookId);
    // O carte respinsă în sesiunea curentă nu revine, chiar dacă a fost și
    // „no" într-o sesiune veche.
    for (const id of all) previouslySwiped.delete(id);

    return { all, previouslySwiped };
  }

  /**
   * Cold start: încă nu știm nimic despre user din swipe-uri.
   *
   * - Dacă userul a bifat genuri favorite la onboarding (pasul de profil de
   *   dinaintea Book Match), batch-ul e 80% din acele genuri și 20%
   *   wildcard-uri din restul catalogului - fără cota de 80%, cardurile de
   *   profil se dilueaza printre atâtea genuri necunoscute încât userul le
   *   simte ca fiind complet random.
   * - Dacă n-a bifat niciun gen, nu avem niciun semnal de la user, deci
   *   pornim de la o listă fixă de titluri populare cross-gen (vezi
   *   COLD_START_FALLBACK_TITLES) în loc să întindem plasa uniform pe tot
   *   catalogul.
   */
  private async coldStartBatch(
    candidates: CandidateBook[],
    size: number,
    favoriteGenres: string[],
    excludedIds: string[],
  ): Promise<BookMatchCard[]> {
    if (favoriteGenres.length === 0) {
      return this.coldStartFallbackBatch(candidates, size, excludedIds);
    }

    const favorites = new Set(favoriteGenres);
    const byGenre = new Map<string, CandidateBook[]>();
    for (const book of candidates) {
      const genre = book.genre ?? '';
      const bucket = byGenre.get(genre);
      if (bucket) bucket.push(book);
      else byGenre.set(genre, [book]);
    }

    const weightOf = (book: CandidateBook) =>
      1 + (book.popularityScore ?? BOOK_MATCH_DEFAULT_POPULARITY);

    // Pool-ul de profil: câte COLD_START_PER_GENRE titluri din fiecare gen
    // favorit, ca un singur gen popular să nu acopere tot batch-ul.
    const favoritePool: CandidateBook[] = [];
    for (const genre of favoriteGenres) {
      const bucket = byGenre.get(genre);
      if (!bucket) continue;
      favoritePool.push(
        ...weightedSample(
          bucket.map((book) => ({ item: book, weight: weightOf(book) })),
          COLD_START_PER_GENRE,
        ),
      );
    }

    const wildcardPool = candidates.filter(
      (book) => !favorites.has(book.genre ?? ''),
    );

    const favoriteTarget = Math.round(size * COLD_START_FAVORITE_RATIO);
    const wildcardTarget = size - favoriteTarget;

    const wildcard = weightedSample(
      wildcardPool.map((book) => ({ item: book, weight: weightOf(book) })),
      wildcardTarget,
    );
    const chosen = new Set(wildcard.map((b) => b.id));
    const profile = weightedSample(
      favoritePool
        .filter((book) => !chosen.has(book.id))
        .map((book) => ({ item: book, weight: weightOf(book) })),
      favoriteTarget,
    );
    for (const book of profile) chosen.add(book.id);

    const pool = [...profile, ...wildcard];
    // Dacă genurile favorite n-au acoperit cota (catalog subțire pe acele
    // genuri), completăm cu orice altceva - mai bine o carte în plus decât
    // un ecran gol.
    if (pool.length < size) {
      for (const book of candidates) {
        if (pool.length >= size) break;
        if (!chosen.has(book.id)) {
          pool.push(book);
          chosen.add(book.id);
        }
      }
    }

    return weightedSample(
      pool.map((item) => ({ item, weight: 1 })),
      size,
    ).map((book) => this.toCard(book, false));
  }

  /**
   * Cold start fără niciun gen favorit declarat: pornim de la titlurile
   * populare cross-gen (COLD_START_FALLBACK_TITLES), interogate direct din
   * DB (nu doar din bazinul `candidates`, care e eșantionat și poate să nu
   * le conțină). Completăm cu genurile din catalog dacă lista fixă nu are
   * destule titluri disponibile (excluse/fără copertă/catalog de test mic).
   */
  private async coldStartFallbackBatch(
    candidates: CandidateBook[],
    size: number,
    excludedIds: string[],
  ): Promise<BookMatchCard[]> {
    const fallbackBooks = await this.prisma.book.findMany({
      where: {
        id: { notIn: excludedIds },
        coverUrl: { not: null },
        title: { in: [...COLD_START_FALLBACK_TITLES], mode: 'insensitive' },
      },
      select: CARD_SELECT,
      take: size,
    });

    const pool = [...fallbackBooks];
    if (pool.length < size) {
      const byGenre = new Map<string, CandidateBook[]>();
      for (const book of candidates) {
        const genre = book.genre ?? '';
        const bucket = byGenre.get(genre);
        if (bucket) bucket.push(book);
        else byGenre.set(genre, [book]);
      }
      const used = new Set(pool.map((b) => b.id));
      for (const genre of BOOK_GENRES) {
        const bucket = byGenre.get(genre);
        if (!bucket) continue;
        for (const book of weightedSample(
          bucket.map((book) => ({
            item: book,
            weight: 1 + (book.popularityScore ?? BOOK_MATCH_DEFAULT_POPULARITY),
          })),
          COLD_START_PER_GENRE,
        )) {
          if (used.has(book.id)) continue;
          pool.push(book);
          used.add(book.id);
        }
      }
      if (pool.length < size) {
        for (const book of candidates) {
          if (pool.length >= size) break;
          if (!used.has(book.id)) {
            pool.push(book);
            used.add(book.id);
          }
        }
      }
    }

    return weightedSample(
      pool.map((item) => ({ item, weight: 1 })),
      size,
    ).map((book) => this.toCard(book, false));
  }

  /**
   * Batch normal: ~3/5 carduri de profil (cele mai potrivite cu scorurile) și
   * ~2/5 discovery (genuri neutre, niciodată genuri respinse). Ambele jumătăți
   * se aleg prin eșantionare ponderată, nu prin sortare fixă, ca două apeluri
   * consecutive să nu întoarcă exact aceleași cărți.
   */
  private personalizedBatch(
    candidates: CandidateBook[],
    scores: UserScoreMaps,
    size: number,
    boosted: boolean,
    previouslySwiped: Set<string>,
  ): BookMatchCard[] {
    const discoveryTarget = discoveryCountFor(size, boosted);
    const profileTarget = size - discoveryTarget;

    const topGenres = new Set(
      [...scores.genre.entries()]
        .filter(([, score]) => score > 0)
        .sort((a, b) => b[1] - a[1])
        .slice(0, TOP_GENRES_FOR_PROFILE)
        .map(([genre]) => genre),
    );

    const isRejectedGenre = (genre: string | null) =>
      genre != null &&
      (scores.genre.get(genre) ?? 0) < NEGATIVE_GENRE_THRESHOLD;

    const profilePool: { item: CandidateBook; weight: number }[] = [];
    const discoveryPool: { item: CandidateBook; weight: number }[] = [];

    for (const book of candidates) {
      if (isRejectedGenre(book.genre)) continue;
      const resurface = this.resurfaceFactor(book, scores, previouslySwiped);
      const genreScore = book.genre ? (scores.genre.get(book.genre) ?? 0) : 0;
      const knownGenre = book.genre != null && scores.genre.has(book.genre);

      if (topGenres.has(book.genre ?? '') || genreScore > 0) {
        const composite = compositeBookScore(book, scores);
        // Deplasăm scorul compus (care poate fi negativ) într-o greutate
        // pozitivă; bonus pentru genurile din top.
        const bonus = topGenres.has(book.genre ?? '') ? 0.5 : 0;
        profilePool.push({
          item: book,
          weight: Math.max(0.05, composite + 1 + bonus) * resurface,
        });
      }
      if (
        !knownGenre ||
        Math.abs(genreScore) <= Math.abs(NEGATIVE_GENRE_THRESHOLD)
      ) {
        discoveryPool.push({ item: book, weight: resurface });
      }
    }

    const discovery = weightedSample(discoveryPool, discoveryTarget);
    const chosen = new Set(discovery.map((b) => b.id));
    const profile = weightedSample(
      profilePool.filter(({ item }) => !chosen.has(item.id)),
      profileTarget,
    );
    for (const book of profile) chosen.add(book.id);

    const cards = [
      ...profile.map((book) => this.toCard(book, false)),
      ...discovery.map((book) => this.toCard(book, true)),
    ];

    // Dacă una dintre jumătăți n-a avut destui candidați (catalog mic sau user
    // care a respins multe genuri), umplem restul cu ce a rămas, marcat ca
    // discovery - e material pe care nu i l-am mai arătat.
    if (cards.length < size) {
      const leftovers = candidates.filter(
        (book) => !chosen.has(book.id) && !isRejectedGenre(book.genre),
      );
      for (const book of weightedSample(
        leftovers.map((item) => ({ item, weight: 1 })),
        size - cards.length,
      )) {
        cards.push(this.toCard(book, true));
      }
    }

    // Amestecăm, altfel toate cardurile de discovery ar veni la coadă și
    // userul ar simți o „a doua parte" mai slabă a sesiunii.
    return weightedSample(
      cards.map((item) => ({ item, weight: 1 })),
      cards.length,
    );
  }

  /**
   * Cât de probabil e să revină o carte respinsă („Nu"/„Skip") într-o sesiune
   * veche: cu cât genul și autorul ei stau mai bine în profilul actual, cu atât
   * mai des. Cărțile nevăzute niciodată au factor 1 (neutru).
   */
  private resurfaceFactor(
    book: CandidateBook,
    scores: UserScoreMaps,
    previouslySwiped: Set<string>,
  ): number {
    if (!previouslySwiped.has(book.id)) return 1;
    const genre = book.genre ? (scores.genre.get(book.genre) ?? 0) : 0;
    const author = book.author ? (scores.author.get(book.author) ?? 0) : 0;
    const affinity = (genre + author) / 2;
    // 0.15 la afinitate 0 (rar, dar nu niciodată), până la 1 la afinitate mare.
    return Math.min(1, Math.max(0.15, 0.15 + affinity * 0.85));
  }

  private toCard(book: CandidateBook, isDiscovery: boolean): BookMatchCard {
    return {
      bookId: book.id,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      genre: book.genre,
      publishedYear: book.publishedYear,
      description: book.description,
      isDiscovery,
    };
  }

  // -------------------------------------------------------------------------
  // Swipe
  // -------------------------------------------------------------------------

  async recordSwipe(
    userId: string,
    input: {
      bookId: string;
      action: BookMatchAction;
      sessionId: string;
      isDiscovery?: boolean;
    },
  ) {
    const book = await this.prisma.book.findUnique({
      where: { id: input.bookId },
      select: { id: true, genre: true, author: true, publishedYear: true },
    });
    if (!book) throw new NotFoundException('Cartea nu a fost găsită');

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        onboardingSwipesCount: true,
        discoveryBoostSwipesRemaining: true,
      },
    });
    if (!user) throw new NotFoundException('Utilizatorul nu a fost găsit');

    await this.prisma.bookSwipe.create({
      data: {
        userId,
        bookId: book.id,
        action: input.action,
        sessionId: input.sessionId,
        isDiscovery: input.isDiscovery ?? false,
      },
    });

    let addedToWishlist = false;
    if (input.action === 'YES') {
      // upsert, nu create: dacă titlul e deja pe wishlist (adăugat manual),
      // `update: {}` îl lasă exact cum e - inclusiv `source: PERSONAL`.
      const before = await this.prisma.wishlistItem.findUnique({
        where: { userId_bookId: { userId, bookId: book.id } },
        select: { id: true },
      });
      await this.prisma.wishlistItem.upsert({
        where: { userId_bookId: { userId, bookId: book.id } },
        create: { userId, bookId: book.id, source: 'BOOK_MATCH' },
        update: {},
      });
      addedToWishlist = !before;
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(user.onboardingSwipesCount < ONBOARDING_SWIPES_TARGET
          ? { onboardingSwipesCount: { increment: 1 } }
          : {}),
        ...(user.discoveryBoostSwipesRemaining > 0
          ? { discoveryBoostSwipesRemaining: { decrement: 1 } }
          : {}),
      },
      select: {
        onboardingSwipesCount: true,
        discoveryBoostSwipesRemaining: true,
      },
    });

    const scores = await this.recomputeTouchedScores(userId, book);

    return {
      recorded: true,
      addedToWishlist,
      onboardingSwipesCount: updatedUser.onboardingSwipesCount,
      discoveryBoostSwipesRemaining: updatedUser.discoveryBoostSwipesRemaining,
      scores,
    };
  }

  /**
   * Recalculează exact cele trei scoruri atinse de cartea votată, re-agregând
   * tot istoricul userului pentru fiecare valoare. E echivalent cu un job
   * periodic care ar recalcula tot (aceeași formulă, aceleași date), doar că se
   * întâmplă la momentul potrivit și atinge 3 rânduri, nu toate.
   */
  private async recomputeTouchedScores(
    userId: string,
    book: {
      genre: string | null;
      author: string | null;
      publishedYear: number | null;
    },
  ) {
    const era = eraForYear(book.publishedYear);
    const cutoff = await this.coldStartCutoff(userId);
    const now = new Date();

    const [genreScore, authorScore, eraScore] = await Promise.all([
      book.genre
        ? this.recomputeDimension(
            userId,
            'genre',
            book.genre,
            { genre: book.genre },
            cutoff,
            now,
          )
        : Promise.resolve(null),
      book.author
        ? this.recomputeDimension(
            userId,
            'author',
            book.author,
            { author: book.author },
            cutoff,
            now,
          )
        : Promise.resolve(null),
      era
        ? this.recomputeDimension(
            userId,
            'era',
            era,
            this.eraFilter(era),
            cutoff,
            now,
          )
        : Promise.resolve(null),
    ]);

    return {
      genre: book.genre ? { value: book.genre, score: genreScore } : null,
      author: book.author ? { value: book.author, score: authorScore } : null,
      era: era ? { value: era, score: eraScore } : null,
    };
  }

  private eraFilter(era: string): Prisma.BookWhereInput {
    const range = yearRangeForEra(era);
    if (!range) return { publishedYear: { lt: 0 } };
    return {
      publishedYear:
        range.from == null
          ? { lt: range.to, gt: 0 }
          : { gte: range.from, lt: range.to },
    };
  }

  private async recomputeDimension(
    userId: string,
    dimension: ScoreDimension,
    value: string,
    bookFilter: Prisma.BookWhereInput,
    coldStartCutoff: Date | null,
    now: Date,
  ): Promise<number> {
    const swipes = await this.prisma.bookSwipe.findMany({
      where: { userId, book: bookFilter },
      select: {
        action: true,
        createdAt: true,
        book: { select: { popularityScore: true } },
      },
    });

    const scored: ScoredSwipe[] = swipes.map((swipe) => ({
      action: swipe.action,
      createdAt: swipe.createdAt,
      multiplier:
        coldStartCutoff == null || swipe.createdAt <= coldStartCutoff
          ? 1 + (swipe.book.popularityScore ?? BOOK_MATCH_DEFAULT_POPULARITY)
          : 1,
    }));

    const score = aggregateScore(scored, dimension, now);

    if (dimension === 'genre') {
      await this.prisma.userGenreScore.upsert({
        where: { userId_genre: { userId, genre: value } },
        create: { userId, genre: value, score },
        update: { score },
      });
    } else if (dimension === 'author') {
      await this.prisma.userAuthorScore.upsert({
        where: { userId_author: { userId, author: value } },
        create: { userId, author: value, score },
        update: { score },
      });
    } else {
      await this.prisma.userEraScore.upsert({
        where: { userId_era: { userId, era: value } },
        create: { userId, era: value, score },
        update: { score },
      });
    }
    return score;
  }

  /**
   * Momentul celui de-al 50-lea swipe al userului: tot ce e mai vechi sau egal
   * a fost dat în cold start și deci a purtat multiplicatorul de popularitate.
   * `null` = userul încă n-a ajuns la 50, toate swipe-urile sunt cold start.
   *
   * Se re-derivă în loc să se stocheze pe rândul de swipe fiindcă e o singură
   * interogare și nu poate ieși din sincron cu istoricul.
   */
  private async coldStartCutoff(userId: string): Promise<Date | null> {
    const rows = await this.prisma.bookSwipe.findMany({
      where: { userId },
      select: { createdAt: true },
      orderBy: { createdAt: 'asc' },
      skip: ONBOARDING_SWIPES_TARGET - 1,
      take: 1,
    });
    return rows[0]?.createdAt ?? null;
  }

  private async loadScores(userId: string): Promise<UserScoreMaps> {
    const [genres, authors, eras] = await Promise.all([
      this.prisma.userGenreScore.findMany({
        where: { userId },
        select: { genre: true, score: true },
      }),
      this.prisma.userAuthorScore.findMany({
        where: { userId },
        select: { author: true, score: true },
      }),
      this.prisma.userEraScore.findMany({
        where: { userId },
        select: { era: true, score: true },
      }),
    ]);
    return {
      genre: new Map(genres.map((r) => [r.genre, r.score])),
      author: new Map(authors.map((r) => [r.author, r.score])),
      era: new Map(eras.map((r) => [r.era, r.score])),
    };
  }

  // -------------------------------------------------------------------------
  // Recalibrare
  // -------------------------------------------------------------------------

  /**
   * „Vreau altceva": comprimă toate scorurile la 40% (nu le șterge - urma
   * preferințelor rămâne, dar nu mai domină) și pornește o fereastră de 20 de
   * swipe-uri cu discovery crescut. O dată la 30 de zile.
   */
  async recalibrate(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { lastRecalibrationAt: true },
    });
    if (!user) throw new NotFoundException('Utilizatorul nu a fost găsit');

    const now = new Date();
    const cooldownEndsAt = this.cooldownEndsAt(user.lastRecalibrationAt, now);
    if (cooldownEndsAt) {
      const daysRemaining = Math.ceil(
        (cooldownEndsAt.getTime() - now.getTime()) / MS_PER_DAY,
      );
      throw new BadRequestException({
        statusCode: 400,
        error: 'RECALIBRATION_COOLDOWN',
        daysRemaining,
        cooldownEndsAt: cooldownEndsAt.toISOString(),
        message: `Îți poți recalibra preferințele o dată la ${RECALIBRATION_COOLDOWN_DAYS} de zile. Mai ai ${daysRemaining} ${daysRemaining === 1 ? 'zi' : 'de zile'} de așteptat.`,
      });
    }

    const before = await this.loadScores(userId);
    const snapshot = (maps: UserScoreMaps) => ({
      genre: Object.fromEntries(maps.genre),
      author: Object.fromEntries(maps.author),
      era: Object.fromEntries(maps.era),
    });
    const scoresBefore = snapshot(before);
    const compress = (map: Map<string, number>) =>
      new Map([...map].map(([k, v]) => [k, v * RECALIBRATION_FACTOR]));
    const after: UserScoreMaps = {
      genre: compress(before.genre),
      author: compress(before.author),
      era: compress(before.era),
    };
    const scoresAfter = snapshot(after);

    await this.prisma.$transaction([
      ...[...after.genre].map(([genre, score]) =>
        this.prisma.userGenreScore.update({
          where: { userId_genre: { userId, genre } },
          data: { score },
        }),
      ),
      ...[...after.author].map(([author, score]) =>
        this.prisma.userAuthorScore.update({
          where: { userId_author: { userId, author } },
          data: { score },
        }),
      ),
      ...[...after.era].map(([era, score]) =>
        this.prisma.userEraScore.update({
          where: { userId_era: { userId, era } },
          data: { score },
        }),
      ),
      this.prisma.user.update({
        where: { id: userId },
        data: {
          lastRecalibrationAt: now,
          discoveryBoostSwipesRemaining: DISCOVERY_BOOST_SWIPES,
        },
      }),
      this.prisma.recalibrationLog.create({
        data: { userId, scoresBefore, scoresAfter },
      }),
    ]);

    return {
      recalibratedAt: now.toISOString(),
      discoveryBoostSwipesRemaining: DISCOVERY_BOOST_SWIPES,
      cooldownEndsAt: new Date(
        now.getTime() + RECALIBRATION_COOLDOWN_DAYS * MS_PER_DAY,
      ).toISOString(),
      scoresBefore,
      scoresAfter,
    };
  }

  private cooldownEndsAt(
    lastRecalibrationAt: Date | null,
    now: Date,
  ): Date | null {
    if (!lastRecalibrationAt) return null;
    const ends = new Date(
      lastRecalibrationAt.getTime() + RECALIBRATION_COOLDOWN_DAYS * MS_PER_DAY,
    );
    return ends.getTime() > now.getTime() ? ends : null;
  }

  // -------------------------------------------------------------------------
  // Status
  // -------------------------------------------------------------------------

  /// „Profilul tău până acum" - ce afișează ecranul de swipe în header/settings.
  async getStatus(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        onboardingSwipesCount: true,
        lastRecalibrationAt: true,
        discoveryBoostSwipesRemaining: true,
      },
    });
    if (!user) throw new NotFoundException('Utilizatorul nu a fost găsit');

    const topGenres = await this.prisma.userGenreScore.findMany({
      where: { userId },
      select: { genre: true, score: true },
      orderBy: { score: 'desc' },
      take: 3,
    });

    const cooldownEndsAt = this.cooldownEndsAt(
      user.lastRecalibrationAt,
      new Date(),
    );

    return {
      onboardingSwipesCount: user.onboardingSwipesCount,
      onboardingTarget: ONBOARDING_SWIPES_TARGET,
      isOnboarding: user.onboardingSwipesCount < ONBOARDING_SWIPES_TARGET,
      lastRecalibrationAt: user.lastRecalibrationAt?.toISOString() ?? null,
      cooldownEndsAt: cooldownEndsAt?.toISOString() ?? null,
      canRecalibrate: cooldownEndsAt == null,
      discoveryBoostSwipesRemaining: user.discoveryBoostSwipesRemaining,
      topGenres,
    };
  }
}

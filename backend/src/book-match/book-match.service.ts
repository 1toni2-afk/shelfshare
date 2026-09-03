import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BOOK_GENRES, GENRE_ADJACENCY } from '../common/constants/book-genres';
import {
  BOOK_MATCH_DEFAULT_POPULARITY,
  DISCOVERY_BOOST_SWIPES,
  DISCOVERY_SERENDIPITY_RATIO,
  NEGATIVE_GENRE_THRESHOLD,
  NEUTRAL_GENRE_BAND,
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

/// Câte swipe-uri trebuie să existe într-un gen ca scorul lui negativ să
/// însemne „gen respins". Sub prag, scorul e o medie peste 1-2 swipe-uri: un
/// singur „Nu" dat unei cărți urâte ar coborî genul sub prag și, cum genurile
/// respinse nu se mai servesc niciodată, genul n-ar mai avea cum să-și revină
/// (nu mai primește swipe-uri => scorul rămâne înghețat sub prag).
const MIN_SWIPES_FOR_GENRE_REJECTION = 3;

/// Câte genuri rămân servibile indiferent de scoruri. Fără această podea, un
/// user care dă mai mult „Nu" decât „Da" (perfect normal: media pe gen scade
/// sub prag la ~3 „Nu" pentru fiecare „Da") ajunge să aibă TOATE genurile
/// respinse - și ecranul de Book Match rămâne gol definitiv. Genurile păstrate
/// sunt cele mai puțin respinse; scorul lor negativ le ține oricum jos în
/// ponderare, doar că nu mai dispar cu totul.
const MIN_ALLOWED_GENRES = 5;

/// Sub atâția candidați, eșantionul TABLESAMPLE e considerat ratat și se
/// reîncearcă printr-o interogare exactă pe index (vezi `sampleCandidates`).
const MIN_CANDIDATE_POOL = 60;

/// Cât luăm din catalogul propriu, verificat manual. Peste mărimea lui de azi
/// (~1900 de titluri, din care ~1560 cu copertă + descriere + gen) DINADINS:
/// interogarea nu are `ORDER BY`, deci o limită mai mică decât catalogul ar
/// întoarce mereu aceleași prime rânduri, iar restul n-ar fi văzute niciodată.
const CURATED_POOL_LIMIT = 5000;

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
    const coldStart = user.onboardingSwipesCount < ONBOARDING_SWIPES_TARGET;

    // Genurile respinse se filtrează în SQL, nu doar în Node: după importul
    // Open Library, un gen rămas servibil poate fi 0.03% din catalog, iar un
    // eșantion oarbă de ~1000 de rânduri nu-l nimerește aproape niciodată -
    // ecranul rămânea gol deși existau sute de cărți valide.
    const scores = coldStart ? null : await this.loadScores(userId);
    const allowed = scores
      ? this.allowedGenres(scores, excluded.genreSwipeCounts)
      : null;

    let candidates = this.dedupeWorks(
      await this.sampleCandidates([...excluded.all], allowed),
      excluded.workKeys,
    );
    // Plasă de siguranță: dacă genurile rămase permise nu mai au nimic de
    // servit, mai bine o carte dintr-un gen respins decât un ecran gol.
    if (candidates.length === 0 && allowed != null) {
      candidates = this.dedupeWorks(
        await this.sampleCandidates([...excluded.all], null),
        excluded.workKeys,
      );
    }
    if (candidates.length === 0) {
      return { sessionId, cards: [] };
    }

    if (scores == null) {
      return {
        sessionId,
        cards: await this.coldStartBatch(
          candidates,
          size,
          user.favoriteGenres,
          [...excluded.all],
          excluded.workKeys,
        ),
      };
    }

    const boosted = user.discoveryBoostSwipesRemaining > 0;
    return {
      sessionId,
      cards: this.personalizedBatch(
        candidates,
        scores,
        size,
        boosted,
        excluded.previouslySwipedWorks,
        allowed,
      ),
    };
  }

  /**
   * Genurile pe care avem voie să le servim. Un gen e respins doar dacă are
   * scor sub prag ȘI destule swipe-uri cât scorul să însemne ceva
   * (MIN_SWIPES_FOR_GENRE_REJECTION); iar dacă respingerile ar lăsa mai puțin
   * de MIN_ALLOWED_GENRES genuri, se readmit cele mai puțin respinse.
   * `null` = nimic de filtrat (calea rapidă, fără condiție pe gen în SQL).
   */
  private allowedGenres(
    scores: UserScoreMaps,
    genreSwipeCounts: Map<string, number>,
  ): string[] | null {
    const known = [...scores.genre.keys()];
    const catalog = [...new Set<string>([...BOOK_GENRES, ...known])];

    const rejected = new Set(
      known.filter(
        (genre) =>
          (scores.genre.get(genre) ?? 0) < NEGATIVE_GENRE_THRESHOLD &&
          (genreSwipeCounts.get(genre) ?? 0) >= MIN_SWIPES_FOR_GENRE_REJECTION,
      ),
    );
    if (rejected.size === 0) return null;

    const readmitCount = MIN_ALLOWED_GENRES - (catalog.length - rejected.size);
    if (readmitCount > 0) {
      const leastRejected = [...rejected]
        .sort((a, b) => (scores.genre.get(b) ?? 0) - (scores.genre.get(a) ?? 0))
        .slice(0, readmitCount);
      for (const genre of leastRejected) rejected.delete(genre);
      if (rejected.size === 0) return null;
    }

    return catalog.filter((genre) => !rejected.has(genre));
  }

  /**
   * Cheia de „operă" a unei cărți: titlu + autor normalizate. Importul Open
   * Library aduce aceeași carte în zeci-sute de ediții, fiecare cu id propriu
   * („Pride and Prejudice" are 286 de rânduri servibile) - fără cheia asta,
   * userul vede același titlu iar și iar, cu altă copertă, și dedublarea pe
   * bookId nu ajută cu nimic. Autorul intră în cheie cu tokenii sortați, ca
   * „Jane Austen" și „Austen, Jane" să dea aceeași cheie.
   */
  private workKey(book: { title: string; author: string | null }): string {
    const norm = (value: string) =>
      value
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
    const author = norm(book.author ?? '')
      .split(' ')
      .sort()
      .join(' ');
    return `${norm(book.title)}|${author}`;
  }

  /// Scoate din bazin operele deja atinse (orice ediție) și păstrează o
  /// singură ediție per operă.
  private dedupeWorks(
    candidates: CandidateBook[],
    excludedWorkKeys: Set<string>,
  ): CandidateBook[] {
    const seen = new Set<string>();
    const out: CandidateBook[] = [];
    for (const book of candidates) {
      const key = this.workKey(book);
      if (excludedWorkKeys.has(key) || seen.has(key)) continue;
      seen.add(key);
      out.push(book);
    }
    return out;
  }

  /**
   * Bazinul de candidați pentru o coadă: catalogul propriu întâi, restul
   * doar ca să acopere ce lipsește.
   */
  private async sampleCandidates(
    excludedIds: string[],
    allowedGenres: string[] | null,
  ): Promise<CandidateBook[]> {
    // Catalogul PROPRIU, verificat manual (~1900 de titluri, vezi
    // `curatedAt`), e prima sursă: are copertă de la editură, descriere în
    // română și genul pus de om. Importul în masă din Open Library rămâne
    // doar plasă de siguranță - de acolo veneau cardurile cu autor greșit
    // („The Road" atribuit lui Jack London) și zecile de ediții ale aceleiași
    // opere.
    const curated = await this.curatedCandidates(excludedIds, allowedGenres);
    if (curated.length >= MIN_CANDIDATE_POOL) return curated;

    // Sub prag (user care a văzut aproape tot catalogul curat, sau un gen pe
    // care catalogul propriu nu-l acoperă) completăm din restul catalogului,
    // fără să renunțăm la ce am găsit curat.
    const wider = await this.wideCatalogCandidates(excludedIds, allowedGenres);
    return [...curated, ...wider];
  }

  /**
   * Candidații din catalogul propriu, verificat manual. Ce ordine iese nu
   * contează pentru rezultat: apelanții eșantionează oricum aleator din bazin
   * (vezi `weightedSample`), iar limita e peste mărimea catalogului curat de
   * azi, deci luăm practic tot ce e disponibil, nu un prim ecran fix.
   *
   * `orderBy` există totuși, și nu e cosmetic: la un `take` fără `orderBy`,
   * Prisma adaugă singur `ORDER BY id ASC`, adică sortează după cheia primară
   * un filtru care alege 1.562 de rânduri din 3,68M - măsurat 20 de SECUNDE
   * per cerere. Sortat după `curatedAt`, planner-ul folosește indexul parțial
   * `books_curated_idx` (vezi migrarea books_curated_index) și scoate aceleași
   * rânduri în ~130ms.
   *
   * Predicatul de aici trebuie deci să rămână identic cu al indexului. Fără
   * index (migrare neaplicată) interogarea rămâne corectă, dar redevine seq
   * scan (~1,4s) - de aici regula migrare-înainte-de-cod.
   */
  private curatedCandidates(
    excludedIds: string[],
    allowedGenres: string[] | null,
  ): Promise<CandidateBook[]> {
    return this.prisma.book.findMany({
      where: {
        curatedAt: { not: null },
        id: { notIn: excludedIds },
        coverUrl: { not: null },
        description: { not: null },
        ...(allowedGenres
          ? { genre: { in: allowedGenres } }
          : { genre: { not: null } }),
      },
      orderBy: { curatedAt: 'asc' },
      select: CARD_SELECT,
      take: CURATED_POOL_LIMIT,
    });
  }

  /**
   * Bazinul din TOT catalogul (inclusiv importul în masă) - vezi
   * `sampleCandidates` pentru când se mai ajunge aici, și comentariul de la
   * `getQueue` pentru de ce nu e un simplu `findMany`. Sub pragul de mărime
   * se comportă identic cu implementarea de dinainte de import (catalog mic
   * => îl luăm tot); peste prag eșantionează fizic (TABLESAMPLE) în loc să
   * sorteze random întreaga tabelă.
   */
  private async wideCatalogCandidates(
    excludedIds: string[],
    allowedGenres: string[] | null,
  ): Promise<CandidateBook[]> {
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
    // La fel excludem metadate insuficiente (fără descriere sau fără gen) -
    // sunt exact cărțile prost taggate din importurile Google Books/Open
    // Library care ajungeau des în discovery pentru că nu se potriveau cu
    // niciun gen cunoscut (vezi `personalizedBatch`).
    if (approxTotal <= CATALOG_SIZE_THRESHOLD_FOR_SAMPLING) {
      // Neschimbat față de implementarea dinainte de import (`notIn: []` e
      // un filtru Prisma valid, echivalent cu "fără restricție").
      return this.prisma.book.findMany({
        where: {
          id: { notIn: excludedIds },
          coverUrl: { not: null },
          description: { not: null },
          ...(allowedGenres
            ? { genre: { in: allowedGenres } }
            : { genre: { not: null } }),
        },
        select: CARD_SELECT,
        take: CANDIDATE_POOL_LIMIT,
      });
    }

    // Marjă x3 față de target: TABLESAMPLE SYSTEM aproximează pe blocuri (nu
    // exact pe rânduri), iar rândurile excluse (inclusiv cele fără copertă)
    // mai reduc din câte rămân utile.
    const samplePercent = Math.min(
      100,
      ((CANDIDATE_POOL_LIMIT * 3) / approxTotal) * 100,
    );

    const notExcluded =
      excludedIds.length > 0
        ? Prisma.sql`AND id NOT IN (${Prisma.join(excludedIds)})`
        : Prisma.empty;
    const genreFilter = allowedGenres
      ? Prisma.sql`AND genre IN (${Prisma.join(allowedGenres)})`
      : Prisma.sql`AND genre IS NOT NULL`;

    const sampled = await this.prisma.$queryRaw<CandidateBook[]>`
      SELECT id, title, author, "coverUrl", genre, "publishedYear", description, "popularityScore"
      FROM books TABLESAMPLE SYSTEM (${samplePercent})
      WHERE "coverUrl" IS NOT NULL
        AND description IS NOT NULL
        ${genreFilter}
        ${notExcluded}
      ORDER BY RANDOM()
      LIMIT ${CANDIDATE_POOL_LIMIT}
    `;
    if (sampled.length >= MIN_CANDIDATE_POOL || allowedGenres == null) {
      return sampled;
    }

    // Eșantion ratat: genurile rămase servibile sunt prea rare ca TABLESAMPLE
    // (care ia blocuri fizice, nu rânduri filtrate) să le nimerească.
    return this.exactCandidates(allowedGenres, notExcluded);
  }

  /**
   * Bazin exact, per gen permis, când eșantionarea fizică nu e de ajuns.
   *
   * Nu `ORDER BY RANDOM()` pe filtrul de gen: planner-ul alege seq scan paralel
   * pe tot catalogul (măsurat 4.4s pe 3.68M de rânduri) fiindcă trebuie oricum
   * să sorteze toate potrivirile. În loc de asta tăiem indexul (genre, id)
   * într-un punct aleator și luăm rândurile imediat de după și de dinainte -
   * două index range scan-uri per gen, ~30ms fiecare, cu un start diferit la
   * fiecare apel (deci nu aceleași cărți de fiecare dată).
   */
  private async exactCandidates(
    allowedGenres: string[],
    notExcluded: Prisma.Sql,
  ): Promise<CandidateBook[]> {
    const half = Math.max(
      1,
      Math.ceil(CANDIDATE_POOL_LIMIT / (allowedGenres.length * 2)),
    );
    const columns = Prisma.sql`SELECT id, title, author, "coverUrl", genre, "publishedYear", description, "popularityScore" FROM books`;

    const parts = allowedGenres.flatMap((genre) => {
      const cut = randomUUID();
      return [
        Prisma.sql`(${columns} WHERE genre = ${genre} AND id >= ${cut}
            AND "coverUrl" IS NOT NULL AND description IS NOT NULL ${notExcluded}
            ORDER BY id LIMIT ${half})`,
        Prisma.sql`(${columns} WHERE genre = ${genre} AND id < ${cut}
            AND "coverUrl" IS NOT NULL AND description IS NOT NULL ${notExcluded}
            ORDER BY id DESC LIMIT ${half})`,
      ];
    });

    return this.prisma.$queryRaw<CandidateBook[]>(
      Prisma.join(parts, ' UNION ALL '),
    );
  }

  /**
   * Cărțile care nu au voie în coadă:
   *  - `all` - orice carte atinsă în sesiunea curentă (regulă dură), plus
   *    orice „Yes" din trecut și orice titlu deja pe wishlist (un „da" duce
   *    cartea pe wishlist, deci n-are sens s-o mai întrebăm), plus cărțile pe
   *    care userul le are deja listate (sunt ale lui).
   *  - `previouslySwiped` - „Nu"/„Skip" din sesiuni anterioare: au voie să
   *    revină, dar cu greutate ajustată de scorurile curente.
   *  - `workKeys` - aceleași cărți, dar ca titlu+autor normalizat: excluderea
   *    pe id lasă să treacă celelalte zeci de ediții ale aceleiași opere din
   *    importul Open Library (vezi `workKey`).
   *
   * Tot de aici ies și `genreSwipeCounts` (câte swipe-uri are userul în
   * fiecare gen), folosite ca prag de încredere pentru respingerea unui gen -
   * fără o interogare în plus, fiindcă oricum citim tot istoricul aici.
   */
  private async excludedBookIds(userId: string, sessionId: string) {
    const bookRef = { select: { title: true, author: true, genre: true } };
    const [swipes, wishlist, owned] = await Promise.all([
      this.prisma.bookSwipe.findMany({
        where: { userId },
        select: { bookId: true, action: true, sessionId: true, book: bookRef },
      }),
      this.prisma.wishlistItem.findMany({
        where: { userId },
        select: { bookId: true, book: bookRef },
      }),
      this.prisma.userBook.findMany({
        where: { userId, deletedAt: null },
        select: { bookId: true, book: bookRef },
      }),
    ]);

    const all = new Set<string>();
    const previouslySwiped = new Set<string>();
    const workKeys = new Set<string>();
    const previouslySwipedWorks = new Set<string>();
    const genreSwipeCounts = new Map<string, number>();

    const rememberWork = (
      book?: {
        title: string;
        author: string | null;
      } | null,
    ) => {
      if (book) workKeys.add(this.workKey(book));
    };

    for (const swipe of swipes) {
      if (swipe.sessionId === sessionId || swipe.action === 'YES') {
        all.add(swipe.bookId);
        rememberWork(swipe.book);
      } else {
        previouslySwiped.add(swipe.bookId);
        if (swipe.book) previouslySwipedWorks.add(this.workKey(swipe.book));
      }
      const genre = swipe.book?.genre;
      if (genre)
        genreSwipeCounts.set(genre, (genreSwipeCounts.get(genre) ?? 0) + 1);
    }
    for (const item of wishlist) {
      all.add(item.bookId);
      rememberWork(item.book);
    }
    for (const item of owned) {
      all.add(item.bookId);
      rememberWork(item.book);
    }
    // O carte respinsă în sesiunea curentă nu revine, chiar dacă a fost și
    // „no" într-o sesiune veche.
    for (const id of all) previouslySwiped.delete(id);
    for (const key of workKeys) previouslySwipedWorks.delete(key);

    return {
      all,
      previouslySwiped,
      previouslySwipedWorks,
      workKeys,
      genreSwipeCounts,
    };
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
    excludedWorkKeys: Set<string>,
  ): Promise<BookMatchCard[]> {
    if (favoriteGenres.length === 0) {
      return this.coldStartFallbackBatch(
        candidates,
        size,
        excludedIds,
        excludedWorkKeys,
      );
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

    const favoriteTarget = Math.round(size * COLD_START_FAVORITE_RATIO);

    // Pool-ul de profil: cel puțin COLD_START_PER_GENRE titluri din fiecare gen
    // favorit, ca un singur gen popular să nu acopere tot batch-ul - dar
    // niciodată atât de puține cât să nu se poată acoperi cota (cu 3 genuri
    // favorite și 4 titluri fiecare, 12 < 16 însemna că restul batch-ului se
    // umplea cu orice, adică exact senzația de „random" pe care cota o evită).
    const perGenre = Math.max(
      COLD_START_PER_GENRE,
      Math.ceil(favoriteTarget / favoriteGenres.length),
    );
    const favoritePool: CandidateBook[] = [];
    for (const genre of favoriteGenres) {
      const bucket = byGenre.get(genre);
      if (!bucket) continue;
      favoritePool.push(
        ...weightedSample(
          bucket.map((book) => ({ item: book, weight: weightOf(book) })),
          perGenre,
        ),
      );
    }

    const wildcardPool = candidates.filter(
      (book) => !favorites.has(book.genre ?? ''),
    );

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
    excludedWorkKeys: Set<string>,
  ): Promise<BookMatchCard[]> {
    // `take` era `size`, fără nicio ordonare: Postgres întoarce aceleași
    // rânduri, în aceeași ordine, la fiecare apel - deci fiecare cont nou
    // primea exact aceleași prime carduri. Luăm toate potrivirile (lista de
    // titluri e fixă și scurtă), le dedublăm pe operă (aceleași titluri
    // populare au zeci de ediții în catalog) și abia apoi eșantionăm.
    // `curatedAt` obligatoriu, ca peste tot în Book Match: pe titlurile
    // populare importul din Open Library are cele mai multe duplicate și cele
    // mai multe atribuiri greșite de autor, adică exact cardurile care arătau
    // rupt. Ce nu găsim curat se completează mai jos din `candidates`, care
    // vine oricum din catalogul propriu.
    const fallbackBooks = await this.prisma.book.findMany({
      where: {
        curatedAt: { not: null },
        id: { notIn: excludedIds },
        coverUrl: { not: null },
        title: { in: [...COLD_START_FALLBACK_TITLES], mode: 'insensitive' },
      },
      select: CARD_SELECT,
    });

    const pool = this.dedupeWorks(fallbackBooks, excludedWorkKeys);
    if (pool.length < size) {
      const byGenre = new Map<string, CandidateBook[]>();
      for (const book of candidates) {
        const genre = book.genre ?? '';
        const bucket = byGenre.get(genre);
        if (bucket) bucket.push(book);
        else byGenre.set(genre, [book]);
      }
      const used = new Set(pool.map((b) => b.id));
      const usedWorks = new Set(pool.map((b) => this.workKey(b)));
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
          if (used.has(book.id) || usedWorks.has(this.workKey(book))) continue;
          pool.push(book);
          used.add(book.id);
          usedWorks.add(this.workKey(book));
        }
      }
      if (pool.length < size) {
        for (const book of candidates) {
          if (pool.length >= size) break;
          if (used.has(book.id) || usedWorks.has(this.workKey(book))) continue;
          pool.push(book);
          used.add(book.id);
          usedWorks.add(this.workKey(book));
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
    previouslySwipedWorks: Set<string>,
    allowedGenres: string[] | null,
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

    // Aceeași listă folosită și în SQL (vezi `allowedGenres`), ca filtrarea în
    // Node să nu poată tăia mai mult decât a cerut interogarea - altfel
    // bazinul rămas s-ar putea goli complet.
    const allowed = allowedGenres ? new Set(allowedGenres) : null;
    const isRejectedGenre = (genre: string | null) =>
      allowed != null && genre != null && !allowed.has(genre);

    // Genuri „vecine" celor din top - discovery-ul controlat le preferă în
    // loc să tragă uniform din tot catalogul eșantionat (vezi GENRE_ADJACENCY).
    const adjacentGenres = new Set<string>();
    for (const genre of topGenres) {
      for (const adjacent of GENRE_ADJACENCY[genre] ?? []) {
        adjacentGenres.add(adjacent);
      }
    }

    const profilePool: { item: CandidateBook; weight: number }[] = [];
    const nearDiscoveryPool: { item: CandidateBook; weight: number }[] = [];
    const farDiscoveryPool: { item: CandidateBook; weight: number }[] = [];

    for (const book of candidates) {
      if (isRejectedGenre(book.genre)) continue;
      const resurface = this.resurfaceFactor(
        book,
        scores,
        previouslySwipedWorks,
      );
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
      if (!knownGenre || Math.abs(genreScore) <= NEUTRAL_GENRE_BAND) {
        // Distanță controlată: un gen vecin celor din top e discovery „aproape"
        // (ex. userul iubește Fantasy, nu a atins încă SF); orice altceva e
        // serendipity - rămâne posibil, dar o cotă mică, nu jumătate din batch.
        if (book.genre != null && adjacentGenres.has(book.genre)) {
          nearDiscoveryPool.push({ item: book, weight: resurface });
        } else {
          farDiscoveryPool.push({ item: book, weight: resurface });
        }
      }
    }

    const serendipityTarget = Math.round(
      discoveryTarget * DISCOVERY_SERENDIPITY_RATIO,
    );
    const nearTarget = discoveryTarget - serendipityTarget;

    const nearDiscovery = weightedSample(nearDiscoveryPool, nearTarget);
    const discoveryChosen = new Set(nearDiscovery.map((b) => b.id));
    const farDiscovery = weightedSample(
      farDiscoveryPool.filter(({ item }) => !discoveryChosen.has(item.id)),
      discoveryTarget - nearDiscovery.length,
    );
    for (const book of farDiscovery) discoveryChosen.add(book.id);

    // Dacă niciuna dintre cele două jumătăți n-a avut destui candidați, se
    // completează din orice discovery rămas (aproape sau depărtat), la fel
    // cum se întâmplă mai jos pentru batch-ul întreg.
    const discoveryRemaining = discoveryTarget - discoveryChosen.size;
    const discoveryFill =
      discoveryRemaining > 0
        ? weightedSample(
            [...nearDiscoveryPool, ...farDiscoveryPool].filter(
              ({ item }) => !discoveryChosen.has(item.id),
            ),
            discoveryRemaining,
          )
        : [];

    const discovery = [...nearDiscovery, ...farDiscovery, ...discoveryFill];
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

    // Ultima plasă: nimic n-a trecut de filtre (toate genurile din bazin sunt
    // respinse). Servim totuși ce avem - un ecran gol e mai rău decât un gen
    // pe care userul l-a notat prost.
    if (cards.length === 0) {
      for (const book of weightedSample(
        candidates.map((item) => ({ item, weight: 1 })),
        size,
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
    previouslySwipedWorks: Set<string>,
  ): number {
    // Pe cheie de operă, nu pe id: altfel „Nu" dat unei ediții din Dracula
    // lăsa celelalte 207 ediții să intre cu factor 1, ca și cum n-ar fi fost
    // văzute niciodată.
    if (!previouslySwipedWorks.has(this.workKey(book))) return 1;
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
      // Dacă titlul e deja pe wishlist (adăugat manual sau ca favorit pe un
      // anunț anume), îl lăsăm exact cum e - inclusiv `source: PERSONAL`.
      // Rândul creat aici e „de titlu" (fără userBookId): un „Yes" în Book
      // Match spune că vrei cartea, nu că vrei exemplarul cuiva anume.
      const before = await this.prisma.wishlistItem.findFirst({
        where: { userId, bookId: book.id },
        select: { id: true },
      });
      if (!before) {
        await this.prisma.wishlistItem.create({
          data: { userId, bookId: book.id, source: 'BOOK_MATCH' },
        });
      }
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

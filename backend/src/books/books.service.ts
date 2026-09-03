import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { BookCondition, Prisma } from '@prisma/client';
import { parse } from 'csv-parse/sync';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { WishlistService } from '../wishlist/wishlist.service';
import { FollowService } from '../follow/follow.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BookLookupService } from './book-lookup.service';
import { AddBookDto } from './dto/add-book.dto';
import { UpdateUserBookDto } from './dto/update-user-book.dto';
import { SearchLibraryDto } from './dto/search-library.dto';
import { ROMANIAN_CITY_COORDINATES } from '../common/constants/romanian-city-coordinates';
import { RomanianCity } from '../common/constants/romanian-cities';
import { haversineDistanceKm } from '../common/utils/geo';
import { publicName } from '../common/utils/user-visibility';
import { awardXp, XP_BOOK_LISTED } from '../common/utils/xp';
import { ListingScoreService } from './listing-score.service';
import { SavedSearchesService } from '../saved-searches/saved-searches.service';
import { ExternalBookResult } from './types/external-book-result';
import { ReviewsService } from '../reviews/reviews.service';
import { ResolveWorkDto } from './dto/resolve-work.dto';

/// Rândul brut întors de căutarea în catalog (`searchCatalog`) - doar
/// coloanele de care are nevoie dropdown-ul de autocomplete.
interface CatalogSearchRow {
  id: string;
  isbn: string | null;
  title: string;
  author: string | null;
  description: string | null;
  coverUrl: string | null;
  publisher: string | null;
  publishedYear: number | null;
  pageCount: number | null;
  language: string | null;
  genre: string | null;
  popularityScore: number | null;
}

const BOOK_CONDITIONS = ['NOUA', 'FOARTE_BUNA', 'BUNA', 'ACCEPTABILA'] as const;
const MAX_LISTING_IMPORT_ROWS = 500;
const MAX_PHOTOS_PER_LISTING = 10;
// Storage-abuse guard: rough cap on total listing photos across a user's
// whole library, well above what any real user would ever legitimately need
// (10 photos x this many listings).
const MAX_TOTAL_LISTING_PHOTOS_PER_USER = 300;

/// Cooldown între două modificări ale prețului de vânzare. Fără el, un anunț
/// putea urca și coborî prețul zilnic ca să pară permanent „redus" - cu
/// prețul vechi tăiat lângă cel nou, asta ar fi devenit o unealtă de marketing
/// fals. 72h e și intervalul în care o reducere reală rămâne vizibilă.
const PRICE_UPDATE_COOLDOWN_MS = 72 * 60 * 60 * 1000;

/**
 * Anunțurile pe care le vede publicul. Un anunț poate fi simultan de mai
 * multe tipuri (și la schimb, și la vânzare), deci vizibilitatea se decide
 * per-tip, nu printr-un flag pe anunț: apare dacă ARE MĂCAR UN tip pe care
 * proprietarul nu l-a ascuns (vezi User în schema.prisma). Aceeași listă e
 * folosită de căutare/discover ȘI de pagina operei, ca un anunț ascuns să nu
 * reapară pe o altă rută.
 */
const PUBLICLY_VISIBLE_LISTING_OR: Prisma.UserBookWhereInput[] = [
  { availableForSwap: true, user: { hideSwapListingsPublic: false } },
  {
    isForSale: true,
    salePrice: { gt: 0 },
    user: { hideSaleListingsPublic: false },
  },
  {
    isForSale: true,
    salePrice: { equals: 0 },
    user: { hideDonationListingsPublic: false },
  },
  { isAuction: true, user: { hideAuctionListingsPublic: false } },
];

const OWNER_SELECT = {
  id: true,
  name: true,
  username: true,
  nameVisible: true,
  city: true,
  rating: true,
  profileImage: true,
} as const;

@Injectable()
export class BooksService {
  private readonly logger = new Logger(BooksService.name);

  constructor(
    private prisma: PrismaService,
    private lookup: BookLookupService,
    private storage: StorageService,
    private wishlist: WishlistService,
    private follow: FollowService,
    private notifications: NotificationsService,
    private listingScore: ListingScoreService,
    private savedSearches: SavedSearchesService,
    private reviews: ReviewsService,
  ) {}

  async searchExternal(query: string) {
    this.logSearch(query);
    // Autocomplete: sărim peste completarea de copertă per rezultat (cereri HTTP
    // suplimentare care făceau dropdown-ul „super greoi" pe cache-miss). Coperta
    // venită gratis în răspunsul de căutare rămâne. `suggestCovers` folosește
    // varianta completă separat, pentru selectorul de coperte.
    //
    // Catalogul propriu se caută ÎN PARALEL cu providerii externi: e singura
    // sursă care are edițiile românești, iar căutarea lui e insensibilă la
    // diacritice - „Stapanul Inelelor" nu întorcea nimic nici de la Google
    // Books (`intitle:` e potrivire de frază exactă), nici de la Open Library
    // (n-are edițiile românești), deși cartea era la noi în bază.
    const [catalog, external] = await Promise.all([
      // Căutarea în catalog depinde de `immutable_unaccent` și de indexul FTS
      // create de migrarea books_diacritic_search. Dacă serverul pornește
      // înaintea migrării, cererea pică pe „function does not exist" - fără
      // prinderea de aici, ar lua cu ea și rezultatele externe, adică tot
      // autocomplete-ul de la „adaugă carte", care mergea și înainte.
      this.searchCatalog(query).catch((error) => {
        this.logger.warn(
          `Căutarea în catalog a eșuat (migrarea books_diacritic_search e aplicată?): ${error}`,
        );
        return [] as ExternalBookResult[];
      }),
      this.lookup.searchByTitle(query, { skipCoverFallback: true }),
    ]);
    return this.mergeSearchResults(query, catalog, external);
  }

  /** Câte rezultate întoarce dropdown-ul de autocomplete, în total. */
  private static readonly _searchResultLimit = 12;

  /**
   * Cuvintele interogării, pregătite pentru `to_tsquery`: fără diacritice,
   * minuscule, doar litere și cifre.
   *
   * Curățarea nu e cosmetică, e de securitate: `to_tsquery` are sintaxă
   * proprie (`&`, `|`, `!`, `:`, paranteze), iar un text liber trimis
   * neatins ar arunca erori de parsare pe orice apostrof sau `&` tastat.
   * Eliminarea diacriticelor trebuie să dea EXACT ce dă `immutable_unaccent`
   * pe partea de index (ă→a, â→a, î→i, ș→s, ț→t), altfel n-am potrivi nimic.
   */
  private toSearchTerms(query: string): string[] {
    return query
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((term) => term.length > 0);
  }

  /**
   * Căutare în catalogul propriu (~3,7M titluri importate), insensibilă la
   * diacritice. Ultimul cuvânt e tratat ca prefix (`:*`), ca autocomplete-ul
   * să găsească ceva și la jumătatea tastării.
   *
   * Sortarea se face pe un lot deja mărginit (CTE-ul de mai jos), nu pe toate
   * potrivirile: un singur cuvânt generic poate potrivi zeci de mii de rânduri
   * din catalog, iar un ORDER BY global pe ele ar face dropdown-ul mai lent
   * decât apelurile externe pe care le completează.
   */
  async searchCatalog(
    query: string,
    limit = BooksService._searchResultLimit,
  ): Promise<ExternalBookResult[]> {
    const terms = this.toSearchTerms(query);
    if (terms.length === 0) return [];
    const tsquery = terms
      .map((term, index) => (index === terms.length - 1 ? `${term}:*` : term))
      .join(' & ');

    const rows = await this.prisma.$queryRaw<CatalogSearchRow[]>`
      WITH matched AS (
        SELECT
          id, isbn, title, author, description, "coverUrl", publisher,
          "publishedYear", "pageCount", language, genre, "popularityScore"
        FROM "books"
        WHERE to_tsvector(
                'simple',
                immutable_unaccent(coalesce("title", '') || ' ' || coalesce("author", ''))
              ) @@ to_tsquery('simple', ${tsquery})
        LIMIT 500
      )
      SELECT * FROM matched
      ORDER BY COALESCE("popularityScore", 0) DESC, length(title) ASC
      LIMIT ${limit}
    `;

    return rows.map((row) => ({
      isbn: row.isbn,
      title: row.title,
      author: row.author,
      description: row.description,
      coverUrl: row.coverUrl,
      publisher: row.publisher,
      publishedYear: row.publishedYear,
      pageCount: row.pageCount,
      language: row.language,
      genre: row.genre,
      subjects: [],
      source: 'catalog' as const,
      bookId: row.id,
    }));
  }

  /**
   * Reunește rezultatele din catalog cu cele externe, fără duplicate.
   *
   * Ordinea: întâi titlurile din catalog care ÎNCEP cu ce a tastat userul
   * (potrivirea cea mai tare pe care o avem), apoi rezultatele externe (au
   * coperte și descrieri mai bogate), apoi restul din catalog. Dedupe pe ISBN
   * când există, altfel pe titlu+autor normalizate.
   */
  private mergeSearchResults(
    query: string,
    catalog: ExternalBookResult[],
    external: ExternalBookResult[],
  ): ExternalBookResult[] {
    const normalizedQuery = this.toSearchTerms(query).join(' ');
    const startsWithQuery = (result: ExternalBookResult) =>
      normalizedQuery.length > 0 &&
      this.toSearchTerms(result.title).join(' ').startsWith(normalizedQuery);

    const ordered = [
      ...catalog.filter(startsWithQuery),
      ...external,
      ...catalog.filter((result) => !startsWithQuery(result)),
    ];

    const seen = new Set<string>();
    const merged: ExternalBookResult[] = [];
    for (const result of ordered) {
      const key = result.isbn
        ? `isbn:${result.isbn.replace(/[-\s]/g, '')}`
        : `ta:${this.toSearchTerms(result.title).join(' ')}|${this.toSearchTerms(result.author ?? '').join(' ')}`;
      if (seen.has(key)) continue;
      seen.add(key);
      merged.push(result);
      if (merged.length >= BooksService._searchResultLimit) break;
    }
    return merged;
  }

  /**
   * Pagina „despre carte": UNA singură per operă, la care duc toate listările
   * (Discover, My Shelf, Search, Book Match) - vezi ruta /work/:bookId.
   *
   * Gruparea edițiilor se face LA INTEROGARE, nu printr-un tabel `Work`:
   * `Book` e per ediție (are isbn, editură, an), iar catalogul are ~3,7M de
   * rânduri importate. Două rânduri sunt aceeași operă dacă titlul ȘI autorul
   * coincid după normalizare (minuscule, fără diacritice). Consecința
   * asumată: edițiile cu titlul scris altfel („Frăția inelului" vs „Stăpânul
   * Inelelor: Frăția Inelului") rămân opere separate.
   *
   * Interogarea trece întâi prin indexul FTS (`books_search_fts_idx`) și abia
   * apoi compară exact - fără prefiltrul indexat, egalitatea pe o expresie
   * neindexată ar fi un seq scan pe tot catalogul.
   */
  async getWork(bookId: string) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    const editions = await this.findEditions(book);
    const editionIds = editions.map((edition) => edition.id);

    const [reviews, listings] = await Promise.all([
      this.reviews.getForBooks(editionIds),
      this.prisma.userBook.findMany({
        where: {
          bookId: { in: editionIds },
          deletedAt: null,
          hiddenAt: null,
          OR: PUBLICLY_VISIBLE_LISTING_OR,
        },
        include: { book: true, user: { select: OWNER_SELECT } },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);

    return {
      book,
      // Ediția curentă e mereu prima, ca dropdown-ul să deschidă pe ce a
      // cerut userul, nu pe cea mai nouă din grup.
      editions,
      reviews,
      listings: listings.map((listing) =>
        this.sanitizeOwner(this.toPublicPhotos(listing)),
      ),
    };
  }

  /**
   * Edițiile aceleiași opere: același titlu și același autor, normalizate.
   * Întoarce ÎNTOTDEAUNA cel puțin cartea dată, chiar dacă titlul ei n-are
   * niciun cuvânt indexabil (titluri numerice, simboluri).
   */
  private async findEditions(book: { id: string; title: string; author: string | null }) {
    const terms = this.toSearchTerms(`${book.title} ${book.author ?? ''}`);
    if (terms.length === 0) {
      const only = await this.prisma.book.findUnique({ where: { id: book.id } });
      return only ? [only] : [];
    }
    const tsquery = terms.join(' & ');

    const rows = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT id FROM "books"
      WHERE to_tsvector(
              'simple',
              immutable_unaccent(coalesce("title", '') || ' ' || coalesce("author", ''))
            ) @@ to_tsquery('simple', ${tsquery})
        AND lower(immutable_unaccent(coalesce("title", ''))) =
            lower(immutable_unaccent(${book.title}))
        AND lower(immutable_unaccent(coalesce("author", ''))) =
            lower(immutable_unaccent(${book.author ?? ''}))
      LIMIT 50
    `;

    const ids = new Set(rows.map((row) => row.id));
    ids.add(book.id);
    const editions = await this.prisma.book.findMany({
      where: { id: { in: [...ids] } },
      orderBy: [{ publishedYear: 'desc' }, { createdAt: 'desc' }],
    });
    // Ediția cerută prima, restul în ordinea de mai sus.
    return [
      ...editions.filter((edition) => edition.id === book.id),
      ...editions.filter((edition) => edition.id !== book.id),
    ];
  }

  /**
   * Deschiderea paginii „despre carte" pornind de la un rezultat de căutare
   * EXTERN (Google Books / Open Library), care n-are încă rând în catalog.
   *
   * Materializăm cartea aici, la deschidere, nu abia la listare: pagina de
   * operă, recenziile și raftul lucrează toate cu un `bookId`, iar fără el
   * fiecare dintre ele ar avea nevoie de o cale paralelă „carte fără id".
   * Dedupe pe ISBN, altfel pe titlu+autor normalizate - aceeași regulă ca la
   * gruparea edițiilor, deci un titlu deja în catalog nu se dublează.
   */
  async resolveWork(dto: ResolveWorkDto): Promise<{ bookId: string }> {
    const cleanIsbn = dto.isbn?.replace(/[-\s]/g, '').trim() || null;
    if (cleanIsbn) {
      const byIsbn = await this.prisma.book.findUnique({
        where: { isbn: cleanIsbn },
      });
      if (byIsbn) return { bookId: byIsbn.id };
    }

    const terms = this.toSearchTerms(`${dto.title} ${dto.author ?? ''}`);
    if (terms.length > 0) {
      const existing = await this.prisma.$queryRaw<{ id: string }[]>`
        SELECT id FROM "books"
        WHERE to_tsvector(
                'simple',
                immutable_unaccent(coalesce("title", '') || ' ' || coalesce("author", ''))
              ) @@ to_tsquery('simple', ${terms.join(' & ')})
          AND lower(immutable_unaccent(coalesce("title", ''))) =
              lower(immutable_unaccent(${dto.title}))
          AND lower(immutable_unaccent(coalesce("author", ''))) =
              lower(immutable_unaccent(${dto.author ?? ''}))
        LIMIT 1
      `;
      if (existing.length > 0) return { bookId: existing[0].id };
    }

    const created = await this.prisma.book.create({
      data: {
        isbn: cleanIsbn,
        title: dto.title,
        author: dto.author,
        coverUrl: dto.coverUrl,
        publisher: dto.publisher,
        publishedYear: dto.publishedYear,
        pageCount: dto.pageCount,
        language: dto.language,
        genre: dto.genre,
        description: dto.description,
        source: dto.source ?? 'search',
      },
    });
    return { bookId: created.id };
  }

  /** Vezi BookLookupService.fetchCoverImage - de ce există proxy-ul ăsta. */
  fetchCoverImage(url: string) {
    return this.lookup.fetchCoverImage(url);
  }

  /**
   * Coperte sugerate (Batch 8) - folosit când user tastează titlu+autor
   * fără să aleagă din autocomplete. Reutilizează searchByTitle (deja
   * cache-uit 5 min) și extrage doar URL-urile de copertă, deduplicate,
   * maxim 4. Titlul e obligatoriu, autorul opțional.
   */
  async suggestCovers(title?: string, author?: string): Promise<string[]> {
    const cleanTitle = title?.trim();
    if (!cleanTitle || cleanTitle.length < 2) return [];
    const results = await this.lookup.searchByTitle(cleanTitle, {
      author: author?.trim() || null,
    });
    const covers = new Set<string>();
    for (const r of results) {
      if (r.coverUrl) covers.add(r.coverUrl);
      if (covers.size >= 4) break;
    }
    return [...covers];
  }

  /**
   * Detalii complete pentru cartea aleasă din autocomplete (descriere +
   * subiecte pentru sugestiile de taguri). Un singur apel, la selecție -
   * `searchExternal` rămâne intenționat „subțire", ca dropdown-ul să nu
   * plătească asta la fiecare tastă.
   */
  async lookupFullDetails(params: {
    isbn?: string;
    title?: string;
    author?: string;
  }) {
    return this.lookup.lookupFullDetails(params);
  }

  async searchLibrary(filters: SearchLibraryDto) {
    if (filters.title) this.logSearch(filters.title);

    const where: Prisma.UserBookWhereInput = {
      // Cărțile din coșul de gunoi al proprietarului (soft-delete) NU trebuie
      // să apară în feed - vezi Milestone 10 batch 2. `hiddenAt` e cealaltă
      // jumătate: anunțul ascuns automat de moderare (vezi ReportsService)
      // iese din căutare, dar rămâne al proprietarului.
      deletedAt: null,
      hiddenAt: null,
      availableForSwap:
        filters.listingType != null
          ? filters.listingType === 'swap'
            ? true
            : undefined
          : filters.availableOnly === 'false'
            ? undefined
            : true,
      isForSale:
        filters.listingType === 'sale' || filters.listingType === 'donation'
          ? true
          : undefined,
      // Donația = anunț la preț 0 (nu avem coloană separată - vezi
      // add_book_screen.dart), deci „sale" trebuie să excludă explicit 0,
      // altfel donațiile ar apărea și la vânzări.
      salePrice:
        filters.listingType === 'donation'
          ? { equals: 0 }
          : filters.listingType === 'sale'
            ? { gt: 0 }
            : undefined,
      isAuction: filters.listingType === 'auction' ? true : undefined,
      condition: filters.condition,
      language: filters.language
        ? { equals: filters.language, mode: 'insensitive' }
        : undefined,
      book: {
        title: filters.title
          ? { contains: filters.title, mode: 'insensitive' }
          : undefined,
        author: filters.author
          ? { contains: filters.author, mode: 'insensitive' }
          : undefined,
        genre: filters.genre
          ? { contains: filters.genre, mode: 'insensitive' }
          : undefined,
      },
      user: filters.city ? { city: filters.city } : undefined,
      // Confidențialitatea anunțurilor (vezi User în schema.prisma): un anunț
      // poate fi simultan de mai multe tipuri (ex. și la schimb, și la
      // vânzare), deci vizibilitatea publică se decide per-tip, nu printr-un
      // singur flag pe anunț. Un anunț apare dacă ARE MĂCAR UN tip pe care
      // proprietarul nu l-a ascuns - dacă toate tipurile lui sunt ascunse,
      // dispare complet din căutare/discover.
      OR: PUBLICLY_VISIBLE_LISTING_OR,
    };

    const fromCoords = filters.fromCity
      ? ROMANIAN_CITY_COORDINATES[filters.fromCity as RomanianCity]
      : undefined;
    const useDistance =
      !!fromCoords &&
      (filters.sort === 'distance' || filters.maxDistanceKm != null);

    if (useDistance) {
      // Distanța nu se poate calcula la nivel de query SQL fără o extensie
      // geo (PostGIS/earthdistance) - luăm un set rezonabil de candidați și
      // calculăm/filtrăm/sortăm în JS. Suficient la scara acestei aplicații,
      // dar nu se scalează la un catalog foarte mare.
      const candidates = await this.prisma.userBook.findMany({
        where,
        include: {
          book: true,
          user: { select: OWNER_SELECT },
          auction: {
            select: {
              id: true,
              currentPrice: true,
              endsAt: true,
              status: true,
              buyNowPrice: true,
            },
          },
        },
        take: 500,
      });

      const withDistance = candidates
        .map((item) => {
          const city = item.user.city as RomanianCity | null;
          const coords = city ? ROMANIAN_CITY_COORDINATES[city] : undefined;
          return {
            ...item,
            distanceKm: coords ? haversineDistanceKm(fromCoords, coords) : null,
          };
        })
        .filter((item) => item.distanceKm !== null)
        .filter(
          (item) =>
            filters.maxDistanceKm == null ||
            item.distanceKm! <= filters.maxDistanceKm,
        )
        .sort((a, b) => a.distanceKm! - b.distanceKm!);

      const total = withDistance.length;
      const items = withDistance
        .slice(filters.offset, filters.offset! + filters.limit!)
        .map((i) => this.sanitizeOwner(this.toPublicPhotos(i)));
      return { items, total, limit: filters.limit, offset: filters.offset };
    }

    // Sortarea implicită (fără alegere explicită din sheet-ul „Sortează", sau
    // aleasă explicit „popularity") - scorul de interes nu e o coloană SQL
    // (vine din ListingScoreEvent, agregat), deci sortăm în JS ca la
    // „distance" mai sus: candidați (doar id-uri, ieftin), scoruri în batch,
    // sortare, apoi datele complete doar pentru pagina cerută.
    const usePopularity = filters.sort === 'popularity' || filters.sort == null;
    if (usePopularity) {
      const candidates = await this.prisma.userBook.findMany({
        where,
        select: { id: true, isPromoted: true, createdAt: true },
      });
      const scores = await this.listingScore.scoresFor(
        candidates.map((c) => c.id),
      );
      const ordered = candidates.sort((a, b) => {
        if (a.isPromoted !== b.isPromoted) return a.isPromoted ? -1 : 1;
        const scoreDiff = (scores.get(b.id) ?? 0) - (scores.get(a.id) ?? 0);
        if (scoreDiff !== 0) return scoreDiff;
        // Fără scor (marea majoritate a anunțurilor), cele mai noi întâi -
        // altfel ordinea printre anunțurile cu scor 0 ar fi arbitrară.
        return b.createdAt.getTime() - a.createdAt.getTime();
      });

      const total = ordered.length;
      const pageIds = ordered
        .slice(filters.offset, filters.offset! + filters.limit!)
        .map((c) => c.id);
      const pageItems = await this.prisma.userBook.findMany({
        where: { id: { in: pageIds } },
        include: {
          book: true,
          user: { select: OWNER_SELECT },
          auction: {
            select: {
              id: true,
              currentPrice: true,
              endsAt: true,
              status: true,
              buyNowPrice: true,
            },
          },
        },
      });
      // Prisma nu garantează ordinea pentru `id: { in }` - o reconstruim din
      // pageIds, care deja are ordinea corectă de scor.
      const byId = new Map(pageItems.map((i) => [i.id, i]));
      const items = pageIds
        .map((id) => byId.get(id))
        .filter((i) => i != null)
        .map((item) => this.sanitizeOwner(this.toPublicPhotos(item)));
      return { items, total, limit: filters.limit, offset: filters.offset };
    }

    // Anunțurile promovate (Premium) apar mereu primele, apoi criteriul de
    // sortare ales - vezi togglePromoted și User.isPremium.
    const orderBy: Prisma.UserBookOrderByWithRelationInput[] = [
      { isPromoted: 'desc' },
      filters.sort === 'mostViewed'
        ? { viewCount: 'desc' }
        : filters.sort === 'oldest'
          ? { createdAt: 'asc' }
          : { createdAt: 'desc' },
    ];

    const [items, total] = await Promise.all([
      this.prisma.userBook.findMany({
        where,
        include: {
          book: true,
          user: { select: OWNER_SELECT },
          auction: {
            select: {
              id: true,
              currentPrice: true,
              endsAt: true,
              status: true,
              buyNowPrice: true,
            },
          },
        },
        orderBy,
        take: filters.limit,
        skip: filters.offset,
      }),
      this.prisma.userBook.count({ where }),
    ]);

    return {
      items: items.map((i) => this.sanitizeOwner(this.toPublicPhotos(i))),
      total,
      limit: filters.limit,
      offset: filters.offset,
    };
  }

  async addToLibrary(userId: string, dto: AddBookDto) {
    const book = await this.findOrCreateBook(dto);

    // isForSale pornește mereu false - vezi comentariul din AddBookDto.
    // Pentru vânzare, userul urcă pozele apoi trece explicit prin
    // updateUserBook (PATCH), care verifică deja că există cel puțin o poză.
    //
    // Câmpurile per-exemplar din Milestone 10 (description, tags, city,
    // edition an=editionYear) se salvează direct pe userBook, distinct de
    // câmpurile pe Book care sunt partajate între toate exemplarele.
    const userBook = await this.prisma.userBook.create({
      data: {
        userId,
        bookId: book.id,
        condition: dto.condition,
        language: dto.language,
        edition:
          dto.edition ??
          (dto.editionYear ? String(dto.editionYear) : undefined),
        isHardcover: dto.isHardcover ?? false,
        isForSale: false,
        description: dto.description,
        tags: dto.tags ?? [],
        city: dto.city,
        mainPhotoUrl: dto.mainPhotoUrl,
      },
      include: { book: true },
    });

    this.wishlist.notifyWishlistedUsers(book.id, userId).catch(() => {});
    this.follow
      .notifyFollowersOfNewBook(userId, book.title, userBook.id)
      .catch(() => {});
    this.notifyNearbyUsers(userId, book.title).catch(() => {});
    this.notifyInterestedUsers(userId, book.title, book.genre).catch(() => {});
    this.savedSearches
      .notifyOnNewListing(userId, book.id, book.title, book.genre, userBook.city)
      .catch(() => {});
    this.notifySeriesFollowers(userId, book).catch(() => {});
    await awardXp(this.prisma, userId, XP_BOOK_LISTED);

    return userBook;
  }

  /**
   * Adăugare în masă (Bulk ISBN Scan / Bulk Listing, Milestone 5) - aceeași
   * stare/limbă pentru toate, câte un userBook per ISBN, procesate secvențial
   * ca să reutilizeze exact logica de la addToLibrary (deduplicare pe ISBN,
   * XP, notificări). Un ISBN care eșuează nu oprește restul listei.
   */
  async bulkAddToLibrary(
    userId: string,
    isbns: string[],
    condition: BookCondition,
    language?: string,
  ) {
    const created: { isbn: string; userBookId: string; title: string }[] = [];
    const failed: { isbn: string; reason: string }[] = [];

    for (const isbn of isbns) {
      try {
        const userBook = await this.addToLibrary(userId, {
          isbn,
          condition,
          language,
        });
        created.push({
          isbn,
          userBookId: userBook.id,
          title: userBook.book.title,
        });
      } catch (error) {
        failed.push({
          isbn,
          reason:
            error instanceof BadRequestException
              ? error.message
              : 'Eroare necunoscută',
        });
      }
    }

    return { created, failed };
  }

  /** Previzualizare titlu/autor/copertă pentru un ISBN scanat, fără să creeze nimic - vezi Bulk ISBN Scan. */
  async lookupIsbnPreview(isbn: string) {
    const cleanIsbn = isbn.replace(/[-\s]/g, '');
    return this.lookup.lookupByIsbn(cleanIsbn);
  }

  /**
   * Import CSV de anunțuri (Seller Tools, Milestone 5) - distinct de
   * importul Goodreads/StoryGraph (acela populează statusul de citit,
   * nu creează anunțuri). Coloane așteptate: title, author, isbn,
   * condition, language. Anunțurile create sunt mereu doar pentru schimb
   * (availableForSwap, isForSale: false) - vânzarea cere cel puțin o poză
   * deja urcată (vezi updateUserBook), imposibil de satisfăcut dintr-un CSV,
   * deci userul trece la vânzare separat, per anunț, după ce urcă poze.
   */
  async importListingsCsv(userId: string, buffer: Buffer) {
    let rows: Record<string, string>[];
    try {
      rows = parse(buffer.toString('utf-8'), {
        columns: true,
        skip_empty_lines: true,
        relax_quotes: true,
        relax_column_count: true,
        bom: true,
        trim: true,
      });
    } catch {
      throw new BadRequestException('Fișierul nu a putut fi citit ca CSV');
    }

    if (rows.length === 0) {
      throw new BadRequestException('Fișierul CSV este gol');
    }
    if (rows.length > MAX_LISTING_IMPORT_ROWS) {
      throw new BadRequestException(
        `Fișierul are prea multe rânduri (maxim ${MAX_LISTING_IMPORT_ROWS})`,
      );
    }

    const created: { title: string; userBookId: string }[] = [];
    const failed: { title: string; reason: string }[] = [];

    for (const row of rows) {
      const title = row['title']?.trim();
      if (!title) {
        failed.push({ title: '(fără titlu)', reason: 'Lipsește titlul' });
        continue;
      }
      const conditionRaw = row['condition']?.trim().toUpperCase();
      const condition: BookCondition =
        conditionRaw &&
        (BOOK_CONDITIONS as readonly string[]).includes(conditionRaw)
          ? (conditionRaw as BookCondition)
          : 'BUNA';

      try {
        const userBook = await this.addToLibrary(userId, {
          title,
          author: row['author']?.trim() || undefined,
          isbn: row['isbn']?.trim().replace(/[-\s]/g, '') || undefined,
          condition,
          language: row['language']?.trim() || undefined,
        });
        created.push({ title, userBookId: userBook.id });
      } catch (error) {
        failed.push({
          title,
          reason:
            error instanceof BadRequestException
              ? error.message
              : 'Eroare necunoscută',
        });
      }
    }

    return { created, failed };
  }

  /**
   * "Nearby Book Listed" - anunță userii din același oraș, EXCLUZÂND
   * followerii proprietarului (ei primesc deja FOLLOWED_USER_NEW_BOOK - nu
   * vrem două notificări pentru același anunț).
   */
  private async notifyNearbyUsers(ownerId: string, bookTitle: string) {
    const owner = await this.prisma.user.findUnique({
      where: { id: ownerId },
      select: { name: true, city: true },
    });
    if (!owner?.city) return;

    const followers = await this.prisma.follow.findMany({
      where: { followingId: ownerId },
      select: { followerId: true },
    });
    const excludeIds = [ownerId, ...followers.map((f) => f.followerId)];

    const nearbyUsers = await this.prisma.user.findMany({
      where: { city: owner.city, id: { notIn: excludeIds } },
      select: { id: true },
      take: 200, // plasă de siguranță - un oraș foarte mare nu ar trebui să inunde toată lumea
    });

    await Promise.all(
      nearbyUsers.map((u) =>
        this.notifications
          .create(
            u.id,
            'NEARBY_BOOK_LISTED',
            `${owner.name ?? 'Un utilizator din orașul tău'} a listat o carte nouă: "${bookTitle}"`,
            { ownerId },
          )
          .catch(() => {}),
      ),
    );
  }

  /**
   * „Carte nouă pe gustul tău" - anunță userii care au genul cărții între
   * preferințele din profilul de cititor (vezi ReadingSurveyDto).
   *
   * Complementară cu notifyNearbyUsers, care merge pe oraș: aici contează ce
   * vrea să citească omul, nu unde stă. Excludem userii din același oraș ca
   * proprietarul, fiindcă ei primesc deja NEARBY_BOOK_LISTED pentru aceeași
   * carte - două notificări pentru un singur anunț ar fi spam.
   */
  private async notifyInterestedUsers(
    ownerId: string,
    bookTitle: string,
    genre: string | null,
  ) {
    if (!genre) return;

    const owner = await this.prisma.user.findUnique({
      where: { id: ownerId },
      select: { city: true },
    });

    const interestedUsers = await this.prisma.user.findMany({
      where: {
        id: { not: ownerId },
        favoriteGenres: { has: genre },
        // Cei din orașul proprietarului au fost deja anunțați de
        // notifyNearbyUsers. `city: null` nu se potrivește cu `not`, deci
        // userii fără oraș setat rămân incluși - corect, ei nu primesc
        // notificarea „din orașul tău".
        ...(owner?.city
          ? { OR: [{ city: null }, { city: { not: owner.city } }] }
          : {}),
      },
      select: { id: true },
      take: 200, // aceeași plasă de siguranță ca la notificarea pe oraș
    });

    await Promise.all(
      interestedUsers.map((u) =>
        this.notifications
          .create(
            u.id,
            'INTEREST_BOOK_LISTED',
            `S-a listat o carte de ${genre}, gen care te interesează: „${bookTitle}"`,
            { ownerId, genre },
          )
          .catch(() => {}),
      ),
    );
  }

  /**
   * "Next Volume in Series" (feature backlog #7) - anunță userii care au pe
   * raft (BookshelfEntry - citite/în curs/wishlist de citit, nu neapărat
   * deținute fizic) un volum ANTERIOR din aceeași serie. `series`/
   * `seriesNumber` sunt completate manual la listare (vezi AddBookDto) -
   * fără ele nu putem ordona volumele, deci sărim tăcut peste cărțile fără
   * serie completată.
   */
  private async notifySeriesFollowers(
    ownerId: string,
    book: { id: string; title: string; series: string | null; seriesNumber: number | null },
  ) {
    if (!book.series || book.seriesNumber == null) return;

    const readers = await this.prisma.bookshelfEntry.findMany({
      where: {
        userId: { not: ownerId },
        book: { series: book.series, seriesNumber: { lt: book.seriesNumber } },
      },
      select: { userId: true },
      distinct: ['userId'],
    });

    await Promise.all(
      readers.map((r) =>
        this.notifications
          .create(
            r.userId,
            'SERIES_VOLUME_AVAILABLE',
            `A apărut un volum nou din seria „${book.series}": „${book.title}"`,
            { bookId: book.id },
          )
          .catch(() => {}),
      ),
    );
  }

  private async findOrCreateBook(dto: AddBookDto) {
    if (dto.bookId) {
      const known = await this.prisma.book.findUnique({
        where: { id: dto.bookId },
      });
      if (!known) {
        throw new BadRequestException('Cartea nu a fost găsită în catalog');
      }
      return known;
    }

    if (dto.isbn) {
      const cleanIsbn = dto.isbn.replace(/[-\s]/g, '');
      const existing = await this.prisma.book.findUnique({
        where: { isbn: cleanIsbn },
      });
      if (existing) return existing;

      const [external, referencePrice] = await Promise.all([
        this.lookup.lookupByIsbn(cleanIsbn),
        this.lookup.lookupPrice(cleanIsbn),
      ]);

      if (external) {
        return this.prisma.book.create({
          data: {
            isbn: cleanIsbn,
            title: external.title,
            author: external.author,
            description: external.description,
            coverUrl: external.coverUrl,
            publisher: external.publisher,
            publishedYear: external.publishedYear,
            pageCount: external.pageCount,
            language: external.language,
            genre: external.genre,
            series: dto.series,
            seriesNumber: dto.seriesNumber,
            source: external.source,
            referencePrice: referencePrice?.price,
            referencePriceCurrency: referencePrice?.currency,
          },
        });
      }

      if (!dto.title) {
        throw new BadRequestException(
          'Nu am găsit cartea după ISBN. Completează manual titlul și autorul.',
        );
      }
      return this.prisma.book.create({
        data: {
          isbn: cleanIsbn,
          title: dto.title,
          author: dto.author,
          series: dto.series,
          seriesNumber: dto.seriesNumber,
          source: 'manual',
          referencePrice: referencePrice?.price,
          referencePriceCurrency: referencePrice?.currency,
        },
      });
    }

    if (!dto.title) {
      throw new BadRequestException('Titlul este obligatoriu dacă nu dai ISBN');
    }
    // Fără ISBN, „findOrCreate" nu poate deduplica exemplarele deja existente
    // pe același titlu - preferăm o carte nouă, ca metadata (genre, publisher,
    // etc.) userului nou să nu suprascrie cea a altui user (proprietar
    // efectiv al entry-ului). Deduplication reală se face doar pe ISBN.
    //
    // Coperta se caută pe titlu + autor: până acum, o carte adăugată fără ISBN
    // rămânea garantat fără copertă, fiindcă tot lookup-ul mergea pe ISBN.
    // Acoperirea nu e totală (titlurile românești lipsesc în bună parte din
    // cataloagele internaționale), de asta clientul mai are și fallback pe poza
    // urcată de proprietar - vezi BookCover.fallbackUrl.
    const coverUrl = await this.lookup.lookupCoverByTitle(
      dto.title,
      dto.author ?? null,
    );

    return this.prisma.book.create({
      data: {
        title: dto.title,
        author: dto.author,
        genre: dto.genre,
        series: dto.series,
        seriesNumber: dto.seriesNumber,
        publisher: dto.publisher,
        publishedYear: dto.publishedYear,
        pageCount: dto.pageCount,
        coverUrl,
        source: 'manual',
      },
    });
  }

  async getMyLibrary(userId: string) {
    const items = await this.prisma.userBook.findMany({
      // Coșul de gunoi (soft-delete) e listat separat prin
      // /books/library/deleted; aici afișăm doar cărțile „vii".
      where: { userId, deletedAt: null },
      include: { book: true },
      orderBy: { createdAt: 'desc' },
    });
    return items.map((i) => this.toPublicPhotos(i));
  }

  async getUserBook(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      include: {
        book: true,
        user: { select: OWNER_SELECT },
        // Fără licitație aici, `auction` venea mereu null pe detaliul unui
        // anunț de tip licitație, iar redirectul spre /auctions/:id din
        // book_detail_screen.dart (singura cale de a licita, fiindcă
        // browse-ul nu distinge tipul la navigare) nu se declanșa niciodată:
        // cardul cu ciocănel deschidea o pagină „Indisponibil".
        auction: {
          select: {
            id: true,
            currentPrice: true,
            endsAt: true,
            status: true,
            buyNowPrice: true,
          },
        },
      },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită în bibliotecă');
    }
    return this.sanitizeOwner(userBook);
  }

  /**
   * Orașele cu cărți disponibile la schimb, cu numărul de anunțuri per oraș -
   * folosit pentru harta de "cărți din apropiere". Nu avem coordonate precise
   * per anunț/utilizator, deci agregăm la nivel de oraș (aceeași sursă de
   * coordonate ca la sortarea după distanță din searchLibrary).
   */
  async getMapCities() {
    const rows = await this.prisma.userBook.findMany({
      where: { availableForSwap: true },
      select: { user: { select: { city: true } } },
    });

    const counts = new Map<string, number>();
    for (const row of rows) {
      const city = row.user.city;
      if (!city) continue;
      counts.set(city, (counts.get(city) ?? 0) + 1);
    }

    return Array.from(counts.entries())
      .map(([city, count]) => {
        const coords = ROMANIAN_CITY_COORDINATES[city as RomanianCity];
        return coords
          ? { city, lat: coords.lat, lng: coords.lng, count }
          : null;
      })
      .filter((entry) => entry !== null);
  }

  async getGenres(query?: string) {
    const rows = await this.prisma.book.groupBy({
      by: ['genre'],
      where: {
        genre: query ? { contains: query, mode: 'insensitive' } : { not: null },
        userBooks: { some: { availableForSwap: true } },
      },
      _count: { genre: true },
      orderBy: query ? { genre: 'asc' } : { _count: { genre: 'desc' } },
      take: query ? 15 : 12,
    });
    return rows.map((r) => ({
      genre: r.genre as string,
      count: r._count.genre,
    }));
  }

  // Sugestii pentru auto-fill la filtrele de căutare (Author/Language) - la
  // fel ca la genre, doar din cărți/anunțuri încă disponibile la schimb, ca
  // sugestiile să nu trimită userul spre căutări fără niciun rezultat.
  async getAuthors(query?: string) {
    const rows = await this.prisma.book.findMany({
      where: {
        author: query
          ? { contains: query, mode: 'insensitive' }
          : { not: null },
        userBooks: { some: { availableForSwap: true } },
      },
      select: { author: true },
      distinct: ['author'],
      orderBy: { author: 'asc' },
      take: 15,
    });
    return rows.map((r) => r.author as string).filter(Boolean);
  }

  async getLanguages(query?: string) {
    const rows = await this.prisma.userBook.findMany({
      where: {
        language: query
          ? { contains: query, mode: 'insensitive' }
          : { not: null },
        availableForSwap: true,
      },
      select: { language: true },
      distinct: ['language'],
      orderBy: { language: 'asc' },
      take: 15,
    });
    return rows.map((r) => r.language as string).filter(Boolean);
  }

  /**
   * Câte transferuri reale (schimb finalizat sau vânzare acceptată) a avut
   * fiecare titlu de carte - baza comună pentru "Most Shared Books" și
   * "Most Popular Authors" (agregăm în JS, nu la nivel SQL, fiindcă
   * evenimentele vin din două tabele diferite - ExchangeRequest și
   * PriceOffer - care nu au o relație comună de grupat direct).
   */
  private async getTransferCountsByBook() {
    const [completedExchanges, acceptedOffers] = await Promise.all([
      this.prisma.exchangeRequest.findMany({
        where: { status: 'COMPLETED' },
        select: { requestedBook: { select: { bookId: true } } },
      }),
      this.prisma.priceOffer.findMany({
        where: { status: 'ACCEPTED' },
        select: { userBook: { select: { bookId: true } } },
      }),
    ]);

    const counts = new Map<string, number>();
    for (const exchange of completedExchanges) {
      const id = exchange.requestedBook.bookId;
      counts.set(id, (counts.get(id) ?? 0) + 1);
    }
    for (const offer of acceptedOffers) {
      const id = offer.userBook.bookId;
      counts.set(id, (counts.get(id) ?? 0) + 1);
    }
    return counts;
  }

  async getMostSharedBooks() {
    const counts = await this.getTransferCountsByBook();
    const topIds = Array.from(counts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15)
      .map(([id]) => id);
    if (topIds.length === 0) return [];

    const books = await this.prisma.book.findMany({
      where: { id: { in: topIds } },
    });
    const byId = new Map(books.map((b) => [b.id, b]));
    return topIds
      .map((id) => {
        const book = byId.get(id);
        return book ? { book, count: counts.get(id)! } : null;
      })
      .filter((entry) => entry !== null);
  }

  async getMostPopularAuthors() {
    const counts = await this.getTransferCountsByBook();
    const bookIds = Array.from(counts.keys());
    if (bookIds.length === 0) return [];

    const books = await this.prisma.book.findMany({
      where: { id: { in: bookIds }, author: { not: null } },
      select: { id: true, author: true },
    });
    const authorCounts = new Map<string, number>();
    for (const book of books) {
      const count = counts.get(book.id) ?? 0;
      authorCounts.set(
        book.author!,
        (authorCounts.get(book.author!) ?? 0) + count,
      );
    }
    return Array.from(authorCounts.entries())
      .map(([author, count]) => ({ author, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 15);
  }

  /**
   * "Trending" - cele mai vizualizate cărți în ultimele 14 zile (spre
   * deosebire de sortarea "mostViewed" din browse, care e all-time).
   */
  /**
   * „Trending": clasament {book, count} - viewer-i UNICI (per user autentificat,
   * cei anonimi contează ca o singură entitate) în ultimele 7 zile. Folosit
   * de pagina de statistici globale.
   */
  async getTrendingBooks() {
    const uniques = await this.trendingUniqueViewers();
    const top = Array.from(uniques.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15);
    if (top.length === 0) return [];
    const books = await this.prisma.book.findMany({
      where: { id: { in: top.map(([id]) => id) } },
    });
    const byId = new Map(books.map((b) => [b.id, b]));
    return top
      .map(([id, count]) => {
        const book = byId.get(id);
        return book ? { book, count } : null;
      })
      .filter((e) => e !== null);
  }

  /**
   * „Cele mai căutate" din Discover (Milestone 20) - anunțurile cu cel mai
   * mare scor de popularitate din ultimele 30 de zile (vezi
   * POPULARITY_WEIGHTS din ListingScoreService), fiecare punct expirând
   * individual, sau overrideul manual de admin dacă există.
   *
   * Scorul rămâne INVIZIBIL pentru userii normali - determină doar ordinea.
   * Doar adminii primesc `searchScore` pe fiecare item (badge de debug în
   * Discover); verificarea se face aici, nu în controller, fiindcă `isAdmin`
   * nu e în JWT (vezi AdminGuard - tot un lookup în DB face).
   *
   * Dacă nu sunt destule anunțuri punctate (instalare nouă, sau după ce toate
   * punctele au expirat), completăm cu cele mai recente anunțuri disponibile,
   * ca secțiunea să nu fie goală.
   */
  async getTrendingListings(viewerId?: string) {
    const TAKE = 20;
    const [scored, viewer] = await Promise.all([
      this.listingScore.topScoringListingIds(TAKE * 2),
      viewerId
        ? this.prisma.user.findUnique({
            where: { id: viewerId },
            select: { isAdmin: true },
          })
        : Promise.resolve(null),
    ]);
    const includeScore = viewer?.isAdmin === true;
    const scoreById = new Map(scored.map((s) => [s.userBookId, s.score]));

    const listings = await this.prisma.userBook.findMany({
      where: {
        id: { in: scored.map((s) => s.userBookId) },
        deletedAt: null,
        hiddenAt: null,
        availableForSwap: true,
      },
      include: { book: true, user: { select: OWNER_SELECT } },
    });
    // Ordinea vine din clasamentul de scor, nu din query (Prisma nu poate
    // sorta după `in`-ul dat), iar anunțurile șterse/indisponibile între timp
    // pică pur și simplu din listă.
    const ordered = listings.sort(
      (a, b) => (scoreById.get(b.id) ?? 0) - (scoreById.get(a.id) ?? 0),
    );

    let result = ordered.slice(0, TAKE);
    if (result.length < TAKE) {
      const fillers = await this.prisma.userBook.findMany({
        where: {
          id: { notIn: result.map((r) => r.id) },
          deletedAt: null,
          hiddenAt: null,
          availableForSwap: true,
        },
        include: { book: true, user: { select: OWNER_SELECT } },
        orderBy: { createdAt: 'desc' },
        take: TAKE - result.length,
      });
      result = [...result, ...fillers];
    }

    return result.map((item) => {
      const dto = this.sanitizeOwner(this.toPublicPhotos(item));
      return includeScore
        ? { ...dto, searchScore: scoreById.get(item.id) ?? 0 }
        : dto;
    });
  }

  /**
   * Scorurile pentru badge-ul de pe cardurile de carte (colțul stânga-sus) -
   * strict admin-only, `{}` pentru orice alt viewer (inclusiv ne-autentificat).
   * Respectă preferința per-admin `User.showAllListingScores`: implicit,
   * badge doar pe cărțile din top 256 la nivel de platformă (vezi
   * ListingScoreService.scoresForCards); un admin poate alege să vadă
   * scorul pe orice carte, din Setări.
   */
  async getListingScoresForCards(
    viewerId: string | undefined,
    userBookIds: string[],
  ): Promise<Record<string, number>> {
    if (!viewerId || userBookIds.length === 0) return {};

    const viewer = await this.prisma.user.findUnique({
      where: { id: viewerId },
      select: { isAdmin: true, showAllListingScores: true },
    });
    if (!viewer?.isAdmin) return {};

    const scores = await this.listingScore.scoresForCards(
      userBookIds,
      viewer.showAllListingScores,
    );
    return Object.fromEntries(scores);
  }

  /// Numără vizualizări unice per carte în ultimele 7 zile. Vizitatorii
  /// ne-autentificați sunt tratați ca o singură entitate, altfel trendingul
  /// s-ar putea umfla cu vizite din tab-uri incognito.
  private async trendingUniqueViewers(): Promise<Map<string, number>> {
    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const views = await this.prisma.bookView.findMany({
      where: { createdAt: { gte: since } },
      select: {
        userId: true,
        userBook: { select: { bookId: true } },
      },
    });
    const perBook = new Map<string, Set<string>>();
    for (const view of views) {
      const bookId = view.userBook.bookId;
      const viewer = view.userId ?? '__anon__';
      const set = perBook.get(bookId) ?? new Set<string>();
      set.add(viewer);
      perBook.set(bookId, set);
    }
    return new Map(
      Array.from(perBook.entries()).map(([id, s]) => [id, s.size]),
    );
  }

  /**
   * „Cele mai dorite": cărțile cu cei mai mulți useri distincți care le-au
   * pus pe wishlist. Semnal pur de cerere, complementar cu `getTrendingBooks`
   * (care măsoară vizionările - atenție, nu neapărat dorință de a primi).
   */
  async getMostWishedBooks() {
    // Gruparea e pe (carte, user), nu doar pe carte: cu favoritele legate de
    // anunț, un singur user poate avea mai multe rânduri pentru același titlu,
    // iar un count brut l-ar număra de mai multe ori.
    const grouped = await this.prisma.wishlistItem.groupBy({
      by: ['bookId', 'userId'],
    });
    const usersPerBook = new Map<string, number>();
    for (const row of grouped) {
      usersPerBook.set(row.bookId, (usersPerBook.get(row.bookId) ?? 0) + 1);
    }
    const topIds = [...usersPerBook.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20)
      .map(([bookId]) => bookId);
    return this.pickListingsForBooks(topIds);
  }

  /// Pentru o listă ordonată de bookId, alege cel mai recent anunț disponibil
  /// la schimb per carte (dacă există) și îl întoarce în format DTO (poze
  /// URL-uri publice, owner sanitizat). Preservează ordinea `bookIds`.
  private async pickListingsForBooks(bookIds: string[]) {
    if (bookIds.length === 0) return [];

    const listings = await this.prisma.userBook.findMany({
      where: { bookId: { in: bookIds }, availableForSwap: true },
      include: { book: true, user: { select: OWNER_SELECT } },
      orderBy: { createdAt: 'desc' },
    });
    const chosen = new Map<string, (typeof listings)[number]>();
    for (const l of listings) {
      if (!chosen.has(l.bookId)) chosen.set(l.bookId, l);
    }

    return bookIds
      .map((id) => {
        const listing = chosen.get(id);
        if (!listing) return null;
        return this.sanitizeOwner(this.toPublicPhotos(listing));
      })
      .filter((e) => e !== null);
  }

  // Fire-and-forget - "Popular Searches" nu trebuie să încetinească
  // răspunsul unei căutări reale, iar un log pierdut ocazional nu contează.
  private logSearch(query: string) {
    const trimmed = query.trim();
    if (!trimmed) return;
    this.prisma.searchLog.create({ data: { query: trimmed } }).catch(() => {});
  }

  /**
   * "Popular Searches" - termenii cei mai căutați în ultimele 30 de zile,
   * normalizați (lowercase) ca variantele de capitalizare să se agrege
   * împreună, dar afișați cu prima variantă întâlnită (nu are rost să
   * inventăm o capitalizare "canonică").
   */
  async getPopularSearches() {
    const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const logs = await this.prisma.searchLog.findMany({
      where: { createdAt: { gte: since } },
      select: { query: true },
      orderBy: { createdAt: 'asc' },
    });

    const counts = new Map<string, { display: string; count: number }>();
    for (const log of logs) {
      const key = log.query.toLowerCase();
      const entry = counts.get(key);
      if (entry) {
        entry.count += 1;
      } else {
        counts.set(key, { display: log.query, count: 1 });
      }
    }

    return Array.from(counts.values())
      .sort((a, b) => b.count - a.count)
      .slice(0, 10)
      .map((entry) => ({ query: entry.display, count: entry.count }));
  }

  /**
   * "Books Near You Today" - anunțuri noi (ultimele 24h), din același oraș
   * ca userul, disponibile la schimb. Reutilizează gruparea pe oraș (nu
   * haversine) - la fel ca restul funcțiilor "city-based" din acest fișier.
   */
  async getNearbyToday(city: string) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const items = await this.prisma.userBook.findMany({
      where: {
        availableForSwap: true,
        createdAt: { gte: since },
        user: { city },
      },
      include: { book: true, user: { select: OWNER_SELECT } },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return items.map((i) => this.sanitizeOwner(this.toPublicPhotos(i)));
  }

  /**
   * „Recomandări pentru tine" (Milestone 20) - rule-based, nu machine
   * learning. Semnalul de gust = genurile ȘI tag-urile cărților pe care
   * userul le-a pus la favorite (wishlist) sau le-a schimbat efectiv
   * (exchange COMPLETED, în oricare din cele două roluri), plus genurile
   * declarate în chestionarul de cititor.
   *
   * Candidații sunt anunțuri disponibile ale altor useri care ating măcar
   * unul din aceste semnale, ordonați după CÂTE semnale ating (un anunț cu
   * genul potrivit ȘI două tag-uri comune bate unul cu doar genul potrivit).
   * Un user fără niciun semnal primește cele mai recente anunțuri, ca să nu
   * vadă o secțiune goală.
   */
  async getRecommendedForYou(userId: string) {
    const [myWishlist, myExchanges, me] = await Promise.all([
      this.prisma.wishlistItem.findMany({
        where: { userId },
        select: { book: { select: { genre: true } } },
      }),
      // Ambele roluri: cartea primită și cea dată spun la fel de mult despre
      // ce citește userul. Ne interesează doar schimburile duse până la capăt.
      this.prisma.exchangeRequest.findMany({
        where: {
          status: 'COMPLETED',
          OR: [{ requesterId: userId }, { ownerId: userId }],
        },
        select: {
          requestedBook: {
            select: { tags: true, book: { select: { genre: true } } },
          },
          offeredBook: {
            select: { tags: true, book: { select: { genre: true } } },
          },
        },
        take: 100,
      }),
      this.prisma.user.findUnique({
        where: { id: userId },
        select: { favoriteGenres: true },
      }),
    ]);

    const genres = new Set<string>();
    const tags = new Set<string>();
    for (const row of myWishlist) {
      if (row.book.genre) genres.add(row.book.genre);
    }
    for (const exchange of myExchanges) {
      for (const listing of [exchange.requestedBook, exchange.offeredBook]) {
        if (!listing) continue;
        if (listing.book.genre) genres.add(listing.book.genre);
        for (const tag of listing.tags) tags.add(tag.toLowerCase());
      }
    }
    // Genurile declarate în chestionarul de cititor contează la fel de mult ca
    // cele deduse din activitate - de fapt sunt singurul semnal pentru un user
    // nou, care n-a schimbat încă nimic și n-are wishlist.
    for (const genre of me?.favoriteGenres ?? []) genres.add(genre);

    if (genres.size === 0 && tags.size === 0) {
      const fallback = await this.prisma.userBook.findMany({
        where: { availableForSwap: true, userId: { not: userId } },
        include: {
          book: true,
          user: { select: OWNER_SELECT },
          auction: {
            select: {
              id: true,
              currentPrice: true,
              endsAt: true,
              status: true,
              buyNowPrice: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 15,
      });
      return fallback.map((i) => this.sanitizeOwner(this.toPublicPhotos(i)));
    }

    const genreList = Array.from(genres);
    const tagList = Array.from(tags);
    const candidates = await this.prisma.userBook.findMany({
      where: {
        deletedAt: null,
        hiddenAt: null,
        availableForSwap: true,
        userId: { not: userId },
        OR: [
          ...(genreList.length ? [{ book: { genre: { in: genreList } } }] : []),
          ...(tagList.length ? [{ tags: { hasSome: tagList } }] : []),
        ],
      },
      include: { book: true, user: { select: OWNER_SELECT } },
      orderBy: { createdAt: 'desc' },
      take: 120,
    });

    // Scor de potrivire = câte semnale atinge anunțul (1 pentru gen + 1 pentru
    // fiecare tag comun). La egalitate rămâne ordinea din query (cel mai
    // recent primul), ca lista să se mai împrospăteze între vizite.
    const scored = candidates.map((item) => {
      let matches = item.book.genre && genres.has(item.book.genre) ? 1 : 0;
      for (const tag of item.tags) {
        if (tags.has(tag.toLowerCase())) matches += 1;
      }
      return { item, matches };
    });

    return scored
      .sort((a, b) => b.matches - a.matches)
      .slice(0, 15)
      .map(({ item }) => this.sanitizeOwner(this.toPublicPhotos(item)));
  }

  /**
   * „Comori ascunse" (Milestone 20) - anunțuri aproape nevăzute (puțini
   * vizitatori UNICI) dar care au primit deja cel puțin o inimă. Combinația
   * asta e ce le face „comori": nu sunt doar necunoscute, ci necunoscute
   * DEȘI cineva le-a vrut.
   *
   * Nu există un concept de „like" separat de wishlist în aplicație (inima de
   * pe anunț adaugă titlul la favorite), deci „cel puțin o inimă" =
   * wishlistItem.count(bookId) >= 1.
   */
  async getHiddenGems() {
    const MAX_UNIQUE_VIEWS = 2;

    // Titlurile cu cel puțin o inimă - punctul de plecare, fiindcă e semnalul
    // rar (mult mai puține titluri au favorite decât au views puține).
    const wished = await this.prisma.wishlistItem.groupBy({
      by: ['bookId'],
      _count: { userId: true },
      orderBy: { _count: { userId: 'asc' } },
      take: 400,
    });
    if (wished.length === 0) return [];

    const candidates = await this.prisma.userBook.findMany({
      where: {
        deletedAt: null,
        hiddenAt: null,
        availableForSwap: true,
        bookId: { in: wished.map((w) => w.bookId) },
        condition: { in: ['NOUA', 'FOARTE_BUNA', 'BUNA'] },
      },
      include: { book: true, user: { select: OWNER_SELECT } },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    if (candidates.length === 0) return [];

    // Numărul de vizitatori unici se ia separat, nu ca `_count` în include -
    // altfel ar trebui scos din obiect înainte de serializare, iar DTO-ul de
    // anunț nu are ce căuta cu un câmp `_count` în el.
    const viewsPerListing = await this.prisma.bookView.groupBy({
      by: ['userBookId'],
      where: { userBookId: { in: candidates.map((c) => c.id) } },
      _count: { _all: true },
    });
    const uniqueViews = new Map(
      viewsPerListing.map((v) => [v.userBookId, v._count._all]),
    );

    return candidates
      .filter((c) => (uniqueViews.get(c.id) ?? 0) <= MAX_UNIQUE_VIEWS)
      .slice(0, 15)
      .map((c) => this.sanitizeOwner(this.toPublicPhotos(c)));
  }

  /**
   * "People with Similar Taste" - alți useri care au listat cărți din
   * aceleași genuri ca userul curent, ordonați după numărul de genuri
   * comune. Fără istoric de citit real (vezi restul aplicației) - genul
   * cărților deja listate e cel mai bun semnal disponibil.
   */
  async getSimilarTasteUsers(userId: string) {
    const myBooks = await this.prisma.userBook.findMany({
      where: { userId },
      select: { book: { select: { genre: true } } },
    });
    const myGenres = new Set(
      myBooks.map((b) => b.book.genre).filter((g): g is string => g !== null),
    );
    if (myGenres.size === 0) return [];

    const others = await this.prisma.userBook.findMany({
      where: {
        userId: { not: userId },
        book: { genre: { in: Array.from(myGenres) } },
      },
      select: {
        userId: true,
        book: { select: { genre: true } },
        user: { select: OWNER_SELECT },
      },
    });

    const overlapByUser = new Map<
      string,
      { user: (typeof others)[number]['user']; genres: Set<string> }
    >();
    for (const row of others) {
      const entry = overlapByUser.get(row.userId) ?? {
        user: row.user,
        genres: new Set<string>(),
      };
      if (row.book.genre) entry.genres.add(row.book.genre);
      overlapByUser.set(row.userId, entry);
    }

    return Array.from(overlapByUser.values())
      .map((entry) => ({
        ...entry.user,
        name: publicName(entry.user),
        sharedGenres: entry.genres.size,
      }))
      .sort((a, b) => b.sharedGenres - a.sharedGenres)
      .slice(0, 15);
  }

  /**
   * "Complete Your Collection" - alte cărți ale acelorași autori pe care
   * userul îi are deja în bibliotecă, dar pe care nu le deține încă.
   * Simplificare deliberată: catalogul nu are un concept de "serie/volum"
   * (ar necesita date externe pe care sursele actuale de lookup nu le dau
   * consistent) - autorul e proxy-ul cel mai apropiat disponibil.
   */
  async getCompleteYourCollection(userId: string) {
    const myBooks = await this.prisma.userBook.findMany({
      where: { userId },
      select: { bookId: true, book: { select: { author: true } } },
    });
    const myBookIds = myBooks.map((b) => b.bookId);
    const myAuthors = new Set(
      myBooks.map((b) => b.book.author).filter((a): a is string => a !== null),
    );
    if (myAuthors.size === 0) return [];

    const items = await this.prisma.userBook.findMany({
      where: {
        availableForSwap: true,
        userId: { not: userId },
        bookId: { notIn: myBookIds },
        book: { author: { in: Array.from(myAuthors) } },
      },
      include: { book: true, user: { select: OWNER_SELECT } },
      orderBy: { createdAt: 'desc' },
      take: 15,
    });
    return items.map((i) => this.sanitizeOwner(this.toPublicPhotos(i)));
  }

  /**
   * "Smart Swap / Auto Match" - dublă coincidență de dorințe: alți useri
   * care (a) au disponibilă o carte pe care userul curent o are pe
   * wishlist, ȘI (b) au pe wishlist-ul lor o carte pe care userul curent
   * o are deja disponibilă. Ăsta e un schimb cu șanse reale de reușită,
   * spre deosebire de o simplă căutare - ambele părți au deja un motiv să
   * accepte.
   */
  async getSmartMatches(userId: string) {
    const [myWishlist, myBooks] = await Promise.all([
      this.prisma.wishlistItem.findMany({
        where: { userId },
        select: { bookId: true },
      }),
      this.prisma.userBook.findMany({
        where: { userId, availableForSwap: true },
        select: {
          id: true,
          bookId: true,
          book: { select: { title: true, coverUrl: true } },
        },
      }),
    ]);
    if (myWishlist.length === 0 || myBooks.length === 0) return [];

    const myWishlistBookIds = myWishlist.map((w) => w.bookId);
    const myBookIds = myBooks.map((b) => b.bookId);

    const candidates = await this.prisma.userBook.findMany({
      where: {
        bookId: { in: myWishlistBookIds },
        availableForSwap: true,
        userId: { not: userId },
      },
      include: { book: true, user: { select: OWNER_SELECT } },
    });
    if (candidates.length === 0) return [];

    const ownerIds = Array.from(new Set(candidates.map((c) => c.userId)));
    const theirWishlists = await this.prisma.wishlistItem.findMany({
      where: { userId: { in: ownerIds }, bookId: { in: myBookIds } },
      select: { userId: true, bookId: true },
    });

    const wantedByOwner = new Map<string, Set<string>>();
    for (const w of theirWishlists) {
      const set = wantedByOwner.get(w.userId) ?? new Set<string>();
      set.add(w.bookId);
      wantedByOwner.set(w.userId, set);
    }
    if (wantedByOwner.size === 0) return [];

    const grouped = new Map<
      string,
      {
        owner: (typeof candidates)[number]['user'];
        theirBooks: typeof candidates;
      }
    >();
    for (const candidate of candidates) {
      if (!wantedByOwner.has(candidate.userId)) continue;
      const entry = grouped.get(candidate.userId) ?? {
        owner: candidate.user,
        theirBooks: [],
      };
      entry.theirBooks.push(candidate);
      grouped.set(candidate.userId, entry);
    }

    return Array.from(grouped.entries()).map(([ownerId, entry]) => {
      const wanted = wantedByOwner.get(ownerId)!;
      const myBooksTheyWant = myBooks.filter((b) => wanted.has(b.bookId));
      return {
        owner: { ...entry.owner, name: publicName(entry.owner) },
        theirBooks: entry.theirBooks.map((c) => ({
          userBookId: c.id,
          title: c.book.title,
          coverUrl: c.book.coverUrl,
        })),
        myBooksTheyWant: myBooksTheyWant.map((b) => ({
          userBookId: b.id,
          title: b.book.title,
          coverUrl: b.book.coverUrl,
        })),
      };
    });
  }

  /**
   * Cărți similare cu un anunț - același gen sau același autor, doar
   * exemplare disponibile, excluzându-l pe cel curent.
   */
  async getSimilarBooks(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      include: { book: true },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    const orConditions: Prisma.BookWhereInput[] = [];
    if (userBook.book.genre) orConditions.push({ genre: userBook.book.genre });
    if (userBook.book.author)
      orConditions.push({ author: userBook.book.author });
    if (orConditions.length === 0) return [];

    const items = await this.prisma.userBook.findMany({
      where: {
        id: { not: userBookId },
        availableForSwap: true,
        book: { OR: orConditions },
      },
      include: {
        book: true,
        // OWNER_SELECT, nu un select inline: acesta include `nameVisible`, de
        // care are nevoie sanitizeOwner. Varianta inline de dinainte îl omitea,
        // deci endpointul (public, fără autentificare) întorcea numele
        // proprietarului chiar dacă acesta îl ascunsese din setări.
        user: { select: OWNER_SELECT },
      },
      take: 10,
    });
    return items.map((i) => this.sanitizeOwner(this.toPublicPhotos(i)));
  }

  /**
   * Istoricul complet al unei cărți fizice de-a lungul lanțului de
   * re-listări (vezi previousListingId) - fiecare verigă e un anunț separat,
   * cu propriul proprietar, stare declarată și poze puse chiar de el.
   */
  async getListingHistory(userBookId: string) {
    const anchor = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
    });
    if (!anchor) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    // Urcăm până la rădăcina lanțului (primul anunț al acestei cărți).
    let root = anchor;
    while (root.previousListingId) {
      const previous = await this.prisma.userBook.findUnique({
        where: { id: root.previousListingId },
      });
      if (!previous) break;
      root = previous;
    }

    // Coborâm din rădăcină prin fiecare re-listare succesivă - lanțul e
    // liniar (un anunț devine indisponibil definitiv după primul transfer,
    // deci are cel mult o singură re-listare care pornește din el).
    const chainIds = [root.id];
    for (;;) {
      const next = await this.prisma.userBook.findFirst({
        where: { previousListingId: chainIds[chainIds.length - 1] },
        select: { id: true },
      });
      if (!next) break;
      chainIds.push(next.id);
    }

    const listings = await this.prisma.userBook.findMany({
      where: { id: { in: chainIds } },
      // `nameVisible` e necesar pentru publicName() de mai jos: endpointul e
      // public, iar lanțul de re-listări expune numele FIECĂRUI proprietar
      // anterior - fără filtru, tocmai userii care își ascunseseră numele
      // apăreau aici, alături de istoricul lor de schimburi.
      include: {
        user: { select: { id: true, name: true, nameVisible: true } },
      },
    });
    const byId = new Map(listings.map((l) => [l.id, l]));

    const transfers = await Promise.all(
      chainIds.map(async (id) => {
        const [offer, exchange] = await Promise.all([
          this.prisma.priceOffer.findFirst({
            where: { userBookId: id, status: 'ACCEPTED' },
          }),
          this.prisma.exchangeRequest.findFirst({
            where: { requestedBookId: id, status: 'COMPLETED' },
          }),
        ]);
        if (offer)
          return { transferredAt: offer.updatedAt, type: 'sale' as const };
        if (exchange)
          return {
            transferredAt: exchange.updatedAt,
            type: 'exchange' as const,
          };
        return { transferredAt: null, type: null };
      }),
    );

    return chainIds
      .map((id, index) => {
        const listing = byId.get(id);
        if (!listing) return null;
        return {
          userBookId: listing.id,
          isCurrent: listing.id === userBookId,
          ownerId: listing.user.id,
          ownerName: publicName(listing.user),
          condition: listing.condition,
          photos: listing.photos.map((p) => this.storage.getPublicUrl(p)),
          listedAt: listing.createdAt,
          transferredAt: transfers[index].transferredAt,
          transferType: transfers[index].type,
        };
      })
      .filter((entry) => entry !== null);
  }

  /**
   * "Price History" (feature backlog #8) - la ce preț s-a vândut EFECTIV
   * acest titlu, nu doar la ce preț e listat acum. Agregăm direct din
   * `PriceOffer` cu status COMPLETED pentru orice exemplar al aceleiași
   * cărți (nu doar anunțul curent) - fără o tabelă nouă, prețul de vânzare
   * final e deja acolo (vezi offers.service.ts, unde oferta trece pe
   * COMPLETED). Schimburile carte-contra-carte nu au preț, deci nu apar aici.
   */
  async getPriceHistory(userBookId: string) {
    const anchor = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      select: { bookId: true },
    });
    if (!anchor) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    const sales = await this.prisma.priceOffer.findMany({
      where: { status: 'COMPLETED', userBook: { bookId: anchor.bookId } },
      select: { amount: true, updatedAt: true },
      orderBy: { updatedAt: 'desc' },
      take: 20,
    });

    if (sales.length === 0) {
      return { averagePrice: null, saleCount: 0, recentSales: [] };
    }

    const amounts = sales.map((s) => Number(s.amount));
    const average = amounts.reduce((a, b) => a + b, 0) / amounts.length;

    return {
      averagePrice: Math.round(average * 100) / 100,
      saleCount: sales.length,
      recentSales: sales.map((s) => ({
        price: Number(s.amount),
        date: s.updatedAt,
      })),
    };
  }

  /**
   * Re-listarea unei cărți primite prin schimb/vânzare - doar destinatarul
   * confirmat (schimb finalizat sau ofertă acceptată pentru acel anunț)
   * poate face asta, o singură dată per anunț original. Noul anunț
   * păstrează același Book din catalog, dar e o listare complet nouă (stare,
   * poze, preț - toate declarate din nou de noul proprietar).
   */
  async relistBook(
    userId: string,
    originalUserBookId: string,
    dto: AddBookDto,
  ) {
    const original = await this.prisma.userBook.findUnique({
      where: { id: originalUserBookId },
    });
    if (!original) {
      throw new NotFoundException('Anunțul original nu a fost găsit');
    }

    const [acceptedOffer, completedExchange] = await Promise.all([
      this.prisma.priceOffer.findFirst({
        where: {
          userBookId: originalUserBookId,
          status: 'ACCEPTED',
          buyerId: userId,
        },
      }),
      this.prisma.exchangeRequest.findFirst({
        where: {
          requestedBookId: originalUserBookId,
          status: 'COMPLETED',
          requesterId: userId,
        },
      }),
    ]);
    if (!acceptedOffer && !completedExchange) {
      throw new ForbiddenException(
        'Poți re-lista doar cărți pe care le-ai primit printr-un schimb finalizat sau o ofertă acceptată',
      );
    }

    const alreadyRelisted = await this.prisma.userBook.findFirst({
      where: { previousListingId: originalUserBookId, userId },
    });
    if (alreadyRelisted) {
      throw new BadRequestException('Ai re-listat deja această carte');
    }

    const userBook = await this.prisma.userBook.create({
      data: {
        userId,
        bookId: original.bookId,
        condition: dto.condition,
        language: dto.language,
        edition: dto.edition,
        isHardcover: dto.isHardcover ?? false,
        isForSale: false,
        previousListingId: originalUserBookId,
      },
      include: { book: true },
    });

    return this.toPublicPhotos(userBook);
  }

  // Folosit doar de endpointul public de detalii - crește viewCount pentru
  // secțiunea "Cele mai vizualizate" de pe home. Fire-and-forget: un view
  // pierdut ocazional nu contează, dar nu trebuie să blocheze afișarea cărții.
  async viewUserBook(userBookId: string, viewerId?: string) {
    const userBook = await this.getUserBook(userBookId);
    this.prisma.userBook
      .update({
        where: { id: userBookId },
        data: { viewCount: { increment: 1 } },
      })
      .catch(() => {});
    if (viewerId) {
      this.prisma.bookView
        .upsert({
          where: { userBookId_userId: { userBookId, userId: viewerId } },
          create: { userBookId, userId: viewerId },
          update: {},
        })
        .catch(() => {});
    }
    // Scorul „Cele mai căutate" (Milestone 20): view unic vs. refresh, cu
    // deduplicare pe 24h - vezi ListingScoreService. Nu punctăm proprietarul
    // care își deschide propriul anunț, altfel oricine și-ar putea urca
    // anunțul în top dând refresh la el.
    if (viewerId !== userBook.userId) {
      this.listingScore.recordView(userBookId, viewerId).catch(() => {});
    }

    // Starea de favorite vine acum de la server, nu din lista de wishlist a
    // clientului: aceea putea fi neîncărcată sau să conțină un alt `book.id`
    // pentru același titlu, iar inima rămânea gri deși cartea era la favorite.
    // `favoriteCount` = câți useri au titlul la favorite (afișat lângă inimă) -
    // distinct pe user, fiindcă favoritele sunt acum pe anunț și același user
    // poate avea inimi pe mai multe exemplare ale titlului.
    const [favoriteUsers, ownFavoriteRows] = await Promise.all([
      this.prisma.wishlistItem.findMany({
        where: { bookId: userBook.bookId },
        distinct: ['userId'],
        select: { userId: true },
      }),
      viewerId
        ? this.prisma.wishlistItem.findMany({
            // Doar favoritul ACESTUI anunț (sau unul „de titlu", venit din
            // Book Match / dinaintea ancorării) aprinde inima - altfel toate
            // anunțurile aceleiași cărți apăreau la favorite deodată.
            where: {
              userId: viewerId,
              bookId: userBook.bookId,
              OR: [{ userBookId }, { userBookId: null }],
            },
            select: { id: true, source: true, userBookId: true },
          })
        : Promise.resolve(
            [] as { id: string; source: string; userBookId: string | null }[],
          ),
    ]);
    const favoriteCount = favoriteUsers.length;
    const ownFavorite =
      ownFavoriteRows.find((row) => row.userBookId === userBookId) ??
      ownFavoriteRows[0] ??
      null;

    return {
      ...this.toPublicPhotos(userBook),
      favoriteCount,
      isWishlisted: !!ownFavorite,
      // Book Match: de unde a ajuns titlul pe wishlist-ul privitorului
      // (PERSONAL / BOOK_MATCH). UI-ul schimbă inima pe o iconiță de „match"
      // pentru rândurile venite din swipe. null = nu e pe wishlist.
      wishlistSource: ownFavorite?.source ?? null,
    };
  }

  // Distinct de viewUserBook (care doar incrementează) - folosit de UI-ul
  // "X vizualizări" ca să arate atât totalul brut (cu refresh-uri), cât și
  // numărul de useri autentificați unici care au deschis anunțul.
  async getViewStats(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      select: { viewCount: true },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită în bibliotecă');
    }
    const unique = await this.prisma.bookView.count({ where: { userBookId } });
    return { total: userBook.viewCount, unique };
  }

  async getPreview(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      select: {
        salePrice: true,
        isForSale: true,
        updatedAt: true,
        book: {
          select: {
            title: true,
            author: true,
            description: true,
            coverUrl: true,
          },
        },
        user: { select: { city: true } },
      },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită în bibliotecă');
    }
    return {
      title: userBook.book.title,
      author: userBook.book.author,
      description: userBook.book.description,
      coverUrl: userBook.book.coverUrl,
      salePrice: userBook.salePrice,
      isForSale: userBook.isForSale,
      city: userBook.user.city,
      updatedAt: userBook.updatedAt,
    };
  }

  async updateUserBook(
    userId: string,
    userBookId: string,
    dto: UpdateUserBookDto,
  ) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    if (dto.isForSale === true && userBook.photos.length === 0) {
      throw new BadRequestException(
        'Trebuie să adaugi cel puțin o poză înainte de a pune cartea la vânzare',
      );
    }

    // Milestone 10: o carte deja transferată către alt user nu poate reveni
    // în stoc, chiar dacă bulk edit-ul cere „marchează ca disponibilă".
    // Vezi permanentlyTransferred setat la exchange COMPLETED.
    if (userBook.permanentlyTransferred && dto.availableForSwap === true) {
      throw new BadRequestException(
        'Cartea a fost deja schimbată și nu mai poate fi făcută disponibilă',
      );
    }

    // Reducere de preț + cooldown de 72h. `salePrice` vine în DTO la fiecare
    // salvare din sheet-ul de editare (chiar dacă userul n-a atins prețul),
    // deci ne uităm la valoarea efectivă, nu la simpla lui prezență.
    const oldPrice =
      userBook.salePrice != null ? Number(userBook.salePrice) : null;
    const newPrice = dto.salePrice;
    const priceChanged =
      newPrice != null && oldPrice != null && newPrice !== oldPrice;
    if (priceChanged && userBook.priceUpdatedAt) {
      const elapsed = Date.now() - userBook.priceUpdatedAt.getTime();
      if (elapsed < PRICE_UPDATE_COOLDOWN_MS) {
        const hoursLeft = Math.ceil(
          (PRICE_UPDATE_COOLDOWN_MS - elapsed) / (60 * 60 * 1000),
        );
        throw new BadRequestException(
          `Prețul a fost modificat recent. Îl poți schimba din nou peste ${hoursLeft} ${
            hoursLeft === 1 ? 'oră' : 'de ore'
          }.`,
        );
      }
    }

    const priceData: Prisma.UserBookUpdateInput = priceChanged
      ? {
          priceUpdatedAt: new Date(),
          // Doar o SCĂDERE lasă în urmă un preț tăiat; o creștere șterge
          // reducerea anterioară, ca să nu rămână afișată o economie care nu
          // mai există.
          previousSalePrice: newPrice < oldPrice ? oldPrice : null,
        }
      : {};
    // Anunț scos de la vânzare - reducerea nu mai are ce afișa.
    if (dto.isForSale === false) {
      priceData.previousSalePrice = null;
    }

    const updated = await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { ...dto, ...priceData },
      include: { book: true },
    });

    // "Price Changed" - doar la o schimbare reală de preț pe un anunț deja
    // la vânzare, nu la prima trecere pe vânzare (acolo se declanșează deja
    // WISHLIST_BOOK_AVAILABLE via notifyWishlistedUsers în altă parte).
    if (
      userBook.isForSale &&
      dto.salePrice != null &&
      userBook.salePrice != null &&
      Number(userBook.salePrice) !== dto.salePrice
    ) {
      this.wishlist
        .notifyPriceChanged(updated.bookId, userId, dto.salePrice)
        .catch(() => {});
    }

    // Prima trecere pe vânzare - abia acum e cunoscut prețul, deci abia
    // acum pot prinde potrivire căutările salvate cu maxPrice (vezi
    // notifyOnNewListing la creare, care sare peste ele fiindcă atunci
    // prețul nu exista încă).
    if (!userBook.isForSale && dto.isForSale === true && updated.salePrice != null) {
      this.savedSearches
        .notifyOnPriceSet(
          userId,
          updated.bookId,
          updated.book.title,
          updated.book.genre,
          updated.city,
          Number(updated.salePrice),
        )
        .catch(() => {});
    }

    return this.toPublicPhotos(updated);
  }

  /** "Promoted Listings" (Premium, Milestone 5) - doar userii isPremium pot promova propriile anunțuri. */
  async togglePromoted(userId: string, userBookId: string) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.isPremium) {
      throw new ForbiddenException(
        'Promovarea anunțurilor este o funcție Premium',
      );
    }

    const updated = await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { isPromoted: !userBook.isPromoted },
      include: { book: true },
    });
    return this.toPublicPhotos(updated);
  }

  /**
   * Soft-delete cu grace period de 7 zile. Cartea nu mai apare în feed / în
   * bibliotecă, dar poate fi restaurată din „Coșul de gunoi" (`GET
   * /books/deleted`). Un cron zilnic o șterge definitiv după expirare, inclusiv
   * pozele din storage - nu ștergem imediat ca să nu pierdem imagini care ar
   * trebui să revină la restore.
   */
  async deleteUserBook(userId: string, userBookId: string) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { deletedAt: new Date(), availableForSwap: false },
    });
    return { message: 'Carte mutată în coșul de gunoi (7 zile)' };
  }

  /**
   * Listează cărțile șterse ale userului care încă sunt în fereastra de
   * restore. Cele mai vechi de 7 zile sunt filtrate aici (chiar dacă cron-ul
   * de curățenie nu a rulat încă, userul nu ar trebui să vadă „false hope").
   */
  async getDeletedUserBooks(userId: string) {
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const items = await this.prisma.userBook.findMany({
      where: {
        userId,
        deletedAt: { not: null, gte: cutoff },
      },
      include: { book: true },
      orderBy: { deletedAt: 'desc' },
    });
    return items.map((i) => this.toPublicPhotos(i));
  }

  /**
   * Restaurează o carte din coșul de gunoi. Availability rămâne pe false -
   * userul o marchează manual „disponibilă" când decide. E deliberat: după
   * o săptămână în coș, poate condiția / prețul s-au schimbat, și cerem un
   * pas conștient înainte să reapară în feed.
   */
  async restoreUserBook(userId: string, userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }
    this.assertOwnership(userBook.userId, userId);
    if (!userBook.deletedAt) {
      throw new BadRequestException('Cartea nu e în coșul de gunoi');
    }

    await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { deletedAt: null },
    });
    return { message: 'Carte restaurată' };
  }

  /**
   * „Emptied Shelves" - cărțile deja transferate (permanentlyTransferred).
   * Rămân vizibile în bibliotecă ca istoric, marcate ca „schimbată/vândută" -
   * user cerea să apară „permanent ca fiind indisponibilă în acea listare".
   */
  async getEmptiedShelves(userId: string) {
    const items = await this.prisma.userBook.findMany({
      where: { userId, permanentlyTransferred: true, deletedAt: null },
      include: { book: true },
      orderBy: { updatedAt: 'desc' },
    });
    return items.map((i) => this.toPublicPhotos(i));
  }

  /**
   * Rulează zilnic la 03:15 - șterge definitiv rândurile din user_books cu
   * `deletedAt` mai vechi de 7 zile, plus pozele lor din storage. Decuplat
   * de `deleteUserBook` (unde am făcut soft-delete) tocmai ca ștergerea reală
   * să fie recuperabilă în intervalul de grace.
   */
  @Cron('15 3 * * *')
  async purgeDeletedUserBooks(): Promise<void> {
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const expired = await this.prisma.userBook.findMany({
      where: { deletedAt: { not: null, lte: cutoff } },
      select: { id: true, photos: true },
    });
    if (expired.length === 0) return;

    this.logger.log(
      `Purge coș gunoi: șterg definitiv ${expired.length} anunțuri`,
    );
    for (const item of expired) {
      try {
        await Promise.all(
          item.photos.map((path) =>
            this.storage.deleteImage(path).catch(() => undefined),
          ),
        );
        await this.prisma.userBook.delete({ where: { id: item.id } });
      } catch (error) {
        this.logger.error(`Nu am putut șterge anunțul ${item.id}`, error);
      }
    }
  }

  async addPhoto(userId: string, userBookId: string, fileBuffer: Buffer) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    if (userBook.photos.length >= MAX_PHOTOS_PER_LISTING) {
      throw new BadRequestException(
        `Poți adăuga maximum ${MAX_PHOTOS_PER_LISTING} poze per anunț`,
      );
    }

    const allPhotos = await this.prisma.userBook.findMany({
      where: { userId },
      select: { photos: true },
    });
    const totalPhotos = allPhotos.reduce((sum, b) => sum + b.photos.length, 0);
    if (totalPhotos >= MAX_TOTAL_LISTING_PHOTOS_PER_USER) {
      throw new BadRequestException(
        'Ai atins limita totală de poze pentru biblioteca ta',
      );
    }

    const path = await this.storage.uploadImage(fileBuffer, 'user-books');

    const updated = await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { photos: { push: path } },
      include: { book: true },
    });

    return {
      ...this.toPublicPhotos(updated),
      photoUrl: this.storage.getPublicUrl(path),
    };
  }

  /**
   * Adaugă în galerie coperta recomandată aleasă la +Share (Google Books/
   * Open Library) - fără upload, doar linkul extern direct. `getPublicUrl`
   * întoarce URL-urile http(s) neschimbate, deci pot sta alături de căile de
   * storage din `photos` fără nicio conversie specială.
   */
  async addPhotoUrl(userId: string, userBookId: string, url: string) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    if (userBook.photos.length >= MAX_PHOTOS_PER_LISTING) {
      throw new BadRequestException(
        `Poți adăuga maximum ${MAX_PHOTOS_PER_LISTING} poze per anunț`,
      );
    }

    const updated = await this.prisma.userBook.update({
      where: { id: userBookId },
      data: { photos: { push: url } },
      include: { book: true },
    });

    return this.toPublicPhotos(updated);
  }

  private assertOwnership(ownerId: string, requesterId: string) {
    if (ownerId !== requesterId) {
      throw new ForbiddenException(
        'Nu poți modifica o carte care nu îți aparține',
      );
    }
  }

  /**
   * `photos` se stochează ca și căi brute în storage (vezi addPhoto) - orice
   * răspuns către client trebuie să le treacă prin asta ca să ajungă URL-uri
   * publice, altfel <img>/Image.network nu are ce afișa.
   */
  private toPublicPhotos<T extends { photos: string[] }>(userBook: T): T {
    return {
      ...userBook,
      photos: userBook.photos.map((p) => this.storage.getPublicUrl(p)),
    };
  }

  private sanitizeOwner<
    T extends { user: { name: string | null; nameVisible: boolean } },
  >(userBook: T): T {
    return {
      ...userBook,
      user: { ...userBook.user, name: publicName(userBook.user) },
    };
  }
}

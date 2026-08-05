import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { firstValueFrom } from 'rxjs';
import { ExternalBookResult } from './types/external-book-result';

@Injectable()
export class BookLookupService {
  private readonly logger = new Logger(BookLookupService.name);

  constructor(private http: HttpService) {}

  /**
   * Open Library pune la un loc genuri reale ("Fiction", "Wizards") cu
   * etichete tehnice faceted gen "series:harry_potter" sau
   * "nyt:series_books=2011-12-18" - luând orbește primul element din
   * `subjects`/`subject` ajungeai des cu eticheta tehnică, nu cu un gen.
   * Acestea folosesc mereu convenția "prefix:valoare", deci le filtrăm.
   */
  private pickGenre(subjects: string[] | undefined): string | null {
    return subjects?.find((s) => !s.includes(':')) ?? null;
  }

  /**
   * Caută o carte după ISBN. Încearcă Open Library întâi; dacă nu găsește
   * nimic sau eșuează, încearcă Google Books.
   *
   * Chiar dacă primul provider răspunde, completăm coperta din celălalt când
   * lipsește: înainte, un rezultat Open Library fără copertă era acceptat ca
   * final și Google Books nu mai era întrebat niciodată, deși de multe ori are
   * imaginea. De aici veneau anunțurile fără copertă.
   */
  async lookupByIsbn(isbn: string): Promise<ExternalBookResult | null> {
    const cleanIsbn = isbn.replace(/[-\s]/g, '');

    const fromOpenLibrary = await this.tryOpenLibraryByIsbn(cleanIsbn);
    if (fromOpenLibrary) {
      return this.withCoverFallback(fromOpenLibrary, cleanIsbn);
    }

    const fromGoogle = await this.tryGoogleBooksByIsbn(cleanIsbn);
    return fromGoogle ? this.withCoverFallback(fromGoogle, cleanIsbn) : null;
  }

  /**
   * Căutare după titlu/text liber - întoarce mai multe rezultate,
   * ca utilizatorul să aleagă ediția corectă.
   *
   * Apelăm Open Library și Google Books în paralel: dacă Open Library
   * răspunde cu rezultate, o folosim (are cover_i inclus, mai bogată pe
   * clasici). Altfel folosim Google Books. Astfel, când Open Library e
   * lentă/goală, nu mai plătim latența ei în serie.
   *
   * Rezultat cache-uit 5 min per query (LRU simplu) - autocomplete cu
   * aceleași litere nu re-apelează API-urile externe.
   */
  /**
   * [skipCoverFallback] sare peste completarea de copertă per rezultat - fiecare
   * rezultat fără `coverUrl` altfel declanșează 1-2 cereri HTTP suplimentare
   * (Google Books + HEAD Open Library), deci pentru 5 rezultate se pot lega până
   * la ~10 cereri externe în serie/paralel, mărginite doar de timeout-ul global
   * de 8s: de aici autocomplete-ul „super greoi" pe cache-miss. Coperta care vine
   * deja gratis în răspunsul de căutare (cover_i / imageLinks) rămâne; doar
   * lookup-ul suplimentar e sărit. Folosit pentru dropdown-ul de autocomplete,
   * unde viteza contează mai mult decât coperta perfectă. `suggestCovers` cere
   * varianta completă (skip=false), deci cache-uim separat pe cheie.
   */
  async searchByTitle(
    query: string,
    opts: { skipCoverFallback?: boolean } = {},
  ): Promise<ExternalBookResult[]> {
    const skip = opts.skipCoverFallback === true;
    const cacheKey = `${query.trim().toLowerCase()}|${skip ? 'nocov' : 'cov'}`;
    const cached = this._searchCache.get(cacheKey);
    const now = Date.now();
    if (cached && now - cached.at < BookLookupService._cacheTtlMs) {
      return cached.results;
    }

    const [fromOpenLibrary, fromGoogle] = await Promise.all([
      this.tryOpenLibrarySearch(query),
      this.tryGoogleBooksSearch(query),
    ]);
    const results = fromOpenLibrary.length > 0 ? fromOpenLibrary : fromGoogle;

    const finalResults = skip
        ? results
        : await Promise.all(
            results.map((result, index) =>
              index < BookLookupService._coverFallbackLimit
                ? this.withCoverFallback(result, result.isbn)
                : Promise.resolve(result),
            ),
          );

    this._searchCache.set(cacheKey, { at: now, results: finalResults });
    if (this._searchCache.size > BookLookupService._cacheMaxEntries) {
      const oldestKey = this._searchCache.keys().next().value;
      if (oldestKey !== undefined) this._searchCache.delete(oldestKey);
    }
    return finalResults;
  }

  /** Câte rezultate de căutare primesc completare de copertă. */
  private static readonly _coverFallbackLimit = 5;

  /** Cache in-memory pentru searchByTitle: TTL 5 min, ~200 chei. */
  private static readonly _cacheTtlMs = 5 * 60 * 1000;
  private static readonly _cacheMaxEntries = 200;
  private readonly _searchCache = new Map<
    string,
    { at: number; results: ExternalBookResult[] }
  >();

  /**
   * Completează `coverUrl` când lipsește, în ordinea: Google Books (are
   * metadate verificabile în JSON) → Open Library Covers pe ISBN.
   *
   * Pentru Open Library Covers folosim `default=false`, altfel serviciul
   * întoarce o imagine-placeholder goală în loc de 404, iar noi am salva un
   * URL care arată o copertă albă. Verificăm cu un HEAD înainte de a-l accepta.
   */
  private async withCoverFallback(
    result: ExternalBookResult,
    isbn: string | null,
  ): Promise<ExternalBookResult> {
    if (result.coverUrl || !isbn) return result;

    const fromGoogle = await this.tryGoogleBooksCover(isbn);
    if (fromGoogle) return { ...result, coverUrl: fromGoogle };

    const openLibraryCover = `https://covers.openlibrary.org/b/isbn/${isbn}-L.jpg?default=false`;
    if (await this.urlExists(openLibraryCover)) {
      return { ...result, coverUrl: openLibraryCover };
    }

    return result;
  }

  /**
   * Coperta unei cărți fără ISBN, căutată pe titlu + autor.
   *
   * Măsurat pe cele 8 titluri fără copertă din baza de date (clasici români),
   * asta recuperează ~3 din 8. Google Books nu are coperte pentru ediții
   * românești, Open Library are pentru unele - de aceea încercăm Open Library
   * întâi aici, invers față de restul serviciului. Restul cazurilor rămân pe
   * seama pozei urcate de proprietar (vezi BookCover.fallbackUrl în client).
   */
  async lookupCoverByTitle(
    title: string,
    author: string | null,
  ): Promise<string | null> {
    const fromOpenLibrary = await this.tryOpenLibraryCoverByTitle(title, author);
    if (fromOpenLibrary) return fromOpenLibrary;

    const results = await this.tryGoogleBooksSearch(
      author ? `${title} ${author}` : title,
    );
    return results.find((r) => r.coverUrl)?.coverUrl ?? null;
  }

  private async tryOpenLibraryCoverByTitle(
    title: string,
    author: string | null,
  ): Promise<string | null> {
    try {
      const params = new URLSearchParams({ title, limit: '10' });
      if (author) params.set('author', author);
      const url = `https://openlibrary.org/search.json?${params.toString()}&fields=cover_i`;

      const { data } = await firstValueFrom(
        this.http.get<{ docs?: { cover_i?: number }[] }>(url),
      );
      const withCover = data.docs?.find((d) => d.cover_i != null);
      return withCover
        ? `https://covers.openlibrary.org/b/id/${withCover.cover_i}-L.jpg`
        : null;
    } catch (error) {
      this.logger.warn(
        `Open Library copertă pe titlu eșuată pentru "${title}": ${error}`,
      );
      return null;
    }
  }

  /** Doar coperta de la Google Books, pentru completarea unui rezultat. */
  private async tryGoogleBooksCover(isbn: string): Promise<string | null> {
    try {
      type GoogleVolume = {
        volumeInfo?: { imageLinks?: { thumbnail?: string } };
      };

      const url = `https://www.googleapis.com/books/v1/volumes?q=isbn:${isbn}`;
      const { data } = await firstValueFrom(
        // Timeout scurt: e doar completare de copertă, nu vrem să blocheze
        // până la timeout-ul global de 8s dacă Google e lent.
        this.http.get<{ items?: GoogleVolume[] }>(url, { timeout: 4000 }),
      );
      const thumbnail = data.items?.[0]?.volumeInfo?.imageLinks?.thumbnail;
      return thumbnail?.replace('http://', 'https://') ?? null;
    } catch (error) {
      this.logger.warn(`Google Books copertă eșuată pentru ISBN ${isbn}: ${error}`);
      return null;
    }
  }

  private async urlExists(url: string): Promise<boolean> {
    try {
      const response = await firstValueFrom(
        this.http.head(url, { timeout: 4000 }),
      );
      return response.status >= 200 && response.status < 300;
    } catch {
      // 404 (nu există copertă) sau timeout - în ambele cazuri nu o folosim.
      return false;
    }
  }

  // ---------- Open Library ----------

  private async tryOpenLibraryByIsbn(
    isbn: string,
  ): Promise<ExternalBookResult | null> {
    try {
      type OpenLibraryBook = {
        title?: string;
        authors?: { name: string }[];
        notes?: string | { value?: string };
        cover?: { large?: string; medium?: string };
        publishers?: { name: string }[];
        publish_date?: string;
        number_of_pages?: number;
        languages?: { key?: string }[];
        subjects?: { name: string }[];
      };

      const url = `https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=data`;
      const { data } = await firstValueFrom(
        this.http.get<Record<string, OpenLibraryBook | undefined>>(url),
      );
      const book = data[`ISBN:${isbn}`];

      if (!book) return null;

      return {
        isbn,
        title: book.title ?? 'Titlu necunoscut',
        author: book.authors?.map((a) => a.name).join(', ') ?? null,
        description:
          typeof book.notes === 'string'
            ? book.notes
            : (book.notes?.value ?? null),
        coverUrl: book.cover?.large ?? book.cover?.medium ?? null,
        publisher: book.publishers?.[0]?.name ?? null,
        publishedYear: this.extractYear(book.publish_date),
        pageCount: book.number_of_pages ?? null,
        language: book.languages?.[0]?.key?.replace('/languages/', '') ?? null,
        genre: this.pickGenre(book.subjects?.map((s) => s.name)),
        source: 'open_library',
      };
    } catch (error) {
      this.logger.warn(
        `Open Library lookup eșuat pentru ISBN ${isbn}: ${error}`,
      );
      return null;
    }
  }

  private async tryOpenLibrarySearch(
    query: string,
  ): Promise<ExternalBookResult[]> {
    try {
      type OpenLibrarySearchDoc = {
        isbn?: string[];
        title?: string;
        author_name?: string[];
        cover_i?: number;
        publisher?: string[];
        first_publish_year?: number;
        number_of_pages_median?: number;
        language?: string[];
        subject?: string[];
      };

      const url = `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=10&fields=isbn,title,author_name,cover_i,publisher,first_publish_year,number_of_pages_median,language,subject`;
      const { data } = await firstValueFrom(
        this.http.get<{ docs?: OpenLibrarySearchDoc[] }>(url),
      );

      return (data.docs ?? []).map((doc): ExternalBookResult => ({
        isbn: doc.isbn?.[0] ?? null,
        title: doc.title ?? 'Titlu necunoscut',
        author: doc.author_name?.join(', ') ?? null,
        description: null, // nu vine în search.json, doar la lookup individual
        coverUrl: doc.cover_i
          ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg`
          : null,
        publisher: doc.publisher?.[0] ?? null,
        publishedYear: doc.first_publish_year ?? null,
        pageCount: doc.number_of_pages_median ?? null,
        language: doc.language?.[0] ?? null,
        genre: this.pickGenre(doc.subject),
        source: 'open_library',
      }));
    } catch (error) {
      this.logger.warn(`Open Library search eșuat pentru "${query}": ${error}`);
      return [];
    }
  }

  // ---------- Google Books (fallback) ----------

  private async tryGoogleBooksByIsbn(
    isbn: string,
  ): Promise<ExternalBookResult | null> {
    const results = await this.tryGoogleBooksSearch(`isbn:${isbn}`);
    return results[0] ?? null;
  }

  private async tryGoogleBooksSearch(
    query: string,
  ): Promise<ExternalBookResult[]> {
    try {
      type GoogleVolume = {
        volumeInfo?: {
          title?: string;
          authors?: string[];
          description?: string;
          imageLinks?: { thumbnail?: string };
          publisher?: string;
          publishedDate?: string;
          pageCount?: number;
          language?: string;
          categories?: string[];
          industryIdentifiers?: { type: string; identifier: string }[];
        };
      };

      const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}`;
      const { data } = await firstValueFrom(
        this.http.get<{ items?: GoogleVolume[] }>(url),
      );

      return (data.items ?? []).map((item): ExternalBookResult => {
        const info = item.volumeInfo ?? {};
        const isbn13 = info.industryIdentifiers?.find(
          (id) => id.type === 'ISBN_13',
        )?.identifier;
        const isbn10 = info.industryIdentifiers?.find(
          (id) => id.type === 'ISBN_10',
        )?.identifier;

        return {
          isbn: isbn13 ?? isbn10 ?? null,
          title: info.title ?? 'Titlu necunoscut',
          author: info.authors?.join(', ') ?? null,
          description: info.description ?? null,
          coverUrl:
            info.imageLinks?.thumbnail?.replace('http://', 'https://') ?? null,
          publisher: info.publisher ?? null,
          publishedYear: this.extractYear(info.publishedDate),
          pageCount: info.pageCount ?? null,
          language: info.language ?? null,
          genre: this.pickGenre(info.categories),
          source: 'google_books',
        };
      });
    } catch (error) {
      this.logger.warn(`Google Books search eșuat pentru "${query}": ${error}`);
      return [];
    }
  }

  /**
   * Prețul de listă al cărții (saleInfo.listPrice de la Google Books), folosit
   * ca preț de referință "din librării". Acoperire parțială - multe cărți nu
   * au preț listat acolo.
   */
  async lookupPrice(
    isbn: string,
  ): Promise<{ price: number; currency: string } | null> {
    try {
      type GoogleVolume = {
        saleInfo?: {
          listPrice?: { amount?: number; currencyCode?: string };
        };
      };

      const url = `https://www.googleapis.com/books/v1/volumes?q=isbn:${isbn}`;
      const { data } = await firstValueFrom(
        this.http.get<{ items?: GoogleVolume[] }>(url),
      );
      const listPrice = data.items?.[0]?.saleInfo?.listPrice;
      if (listPrice?.amount != null && listPrice?.currencyCode) {
        return { price: listPrice.amount, currency: listPrice.currencyCode };
      }
      return null;
    } catch (error) {
      this.logger.warn(`Google Books preț eșuat pentru ISBN ${isbn}: ${error}`);
      return null;
    }
  }

  private extractYear(dateStr?: string): number | null {
    if (!dateStr) return null;
    const match = dateStr.match(/\d{4}/);
    return match ? parseInt(match[0], 10) : null;
  }
}

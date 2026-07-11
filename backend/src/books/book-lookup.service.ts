import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { firstValueFrom } from 'rxjs';
import { ExternalBookResult } from './types/external-book-result';

@Injectable()
export class BookLookupService {
  private readonly logger = new Logger(BookLookupService.name);

  constructor(private http: HttpService) {}

  /**
   * Caută o carte după ISBN. Încearcă Open Library întâi; dacă nu găsește
   * nimic sau eșuează, încearcă Google Books.
   */
  async lookupByIsbn(isbn: string): Promise<ExternalBookResult | null> {
    const cleanIsbn = isbn.replace(/[-\s]/g, '');

    const fromOpenLibrary = await this.tryOpenLibraryByIsbn(cleanIsbn);
    if (fromOpenLibrary) return fromOpenLibrary;

    return this.tryGoogleBooksByIsbn(cleanIsbn);
  }

  /**
   * Căutare după titlu/text liber - întoarce mai multe rezultate,
   * ca utilizatorul să aleagă ediția corectă.
   */
  async searchByTitle(query: string): Promise<ExternalBookResult[]> {
    const fromOpenLibrary = await this.tryOpenLibrarySearch(query);
    if (fromOpenLibrary.length > 0) return fromOpenLibrary;

    return this.tryGoogleBooksSearch(query);
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
        genre: book.subjects?.[0]?.name ?? null,
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

      return (data.docs ?? []).map(
        (doc): ExternalBookResult => ({
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
          genre: doc.subject?.[0] ?? null,
          source: 'open_library',
        }),
      );
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
          genre: info.categories?.[0] ?? null,
          source: 'google_books',
        };
      });
    } catch (error) {
      this.logger.warn(`Google Books search eșuat pentru "${query}": ${error}`);
      return [];
    }
  }

  private extractYear(dateStr?: string): number | null {
    if (!dateStr) return null;
    const match = dateStr.match(/\d{4}/);
    return match ? parseInt(match[0], 10) : null;
  }
}

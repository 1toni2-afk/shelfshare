import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { firstValueFrom } from 'rxjs';
import { ExternalBookResult } from './types/external-book-result';

@Injectable()
export class BookLookupService {
  private readonly logger = new Logger(BookLookupService.name);

  constructor(private http: HttpService) {}

  async lookupByIsbn(isbn: string): Promise<ExternalBookResult | null> {
    const cleanIsbn = isbn.replace(/[-\s]/g, '');

    const fromOpenLibrary = await this.tryOpenLibraryByIsbn(cleanIsbn);
    if (fromOpenLibrary) return fromOpenLibrary;

    return this.tryGoogleBooksByIsbn(cleanIsbn);
  }

  async searchByTitle(query: string): Promise<ExternalBookResult[]> {
    const fromOpenLibrary = await this.tryOpenLibrarySearch(query);
    if (fromOpenLibrary.length > 0) return fromOpenLibrary;

    return this.tryGoogleBooksSearch(query);
  }

  private async tryOpenLibraryByIsbn(
    isbn: string,
  ): Promise<ExternalBookResult | null> {
    try {
      const url = `https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=data`;
      const { data } = await firstValueFrom(this.http.get(url));
      const book = data[`ISBN:${isbn}`];

      if (!book) return null;

      return {
        isbn,
        title: book.title ?? 'Titlu necunoscut',
        author: book.authors?.map((a: { name: string }) => a.name).join(', ') ?? null,
        description:
          typeof book.notes === 'string' ? book.notes : (book.notes?.value ?? null),
        coverUrl: book.cover?.large ?? book.cover?.medium ?? null,
        publisher: book.publishers?.[0]?.name ?? null,
        publishedYear: this.extractYear(book.publish_date),
        pageCount: book.number_of_pages ?? null,
        language: book.languages?.[0]?.key?.replace('/languages/', '') ?? null,
        source: 'open_library',
      };
    } catch (error) {
      this.logger.warn(`Open Library lookup eșuat pentru ISBN ${isbn}: ${error}`);
      return null;
    }
  }

  private async tryOpenLibrarySearch(
    query: string,
  ): Promise<ExternalBookResult[]> {
    try {
      const url = `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=10`;
      const { data } = await firstValueFrom(this.http.get(url));

      return (data.docs ?? []).map(
        (doc: {
          isbn?: string[];
          title?: string;
          author_name?: string[];
          cover_i?: number;
          publisher?: string[];
          first_publish_year?: number;
          number_of_pages_median?: number;
          language?: string[];
        }): ExternalBookResult => ({
          isbn: doc.isbn?.[0] ?? null,
          title: doc.title ?? 'Titlu necunoscut',
          author: doc.author_name?.join(', ') ?? null,
          description: null,
          coverUrl: doc.cover_i
            ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg`
            : null,
          publisher: doc.publisher?.[0] ?? null,
          publishedYear: doc.first_publish_year ?? null,
          pageCount: doc.number_of_pages_median ?? null,
          language: doc.language?.[0] ?? null,
          source: 'open_library',
        }),
      );
    } catch (error) {
      this.logger.warn(`Open Library search eșuat pentru "${query}": ${error}`);
      return [];
    }
  }

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
      const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}`;
      const { data } = await firstValueFrom(this.http.get(url));

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
          industryIdentifiers?: { type: string; identifier: string }[];
        };
      };

      return (data.items ?? []).map((item: GoogleVolume): ExternalBookResult => {
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
          coverUrl: info.imageLinks?.thumbnail?.replace('http://', 'https://') ?? null,
          publisher: info.publisher ?? null,
          publishedYear: this.extractYear(info.publishedDate),
          pageCount: info.pageCount ?? null,
          language: info.language ?? null,
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

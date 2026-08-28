import { Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service';

type GoogleVolume = {
  volumeInfo?: {
    description?: string;
    industryIdentifiers?: { identifier?: string }[];
  };
};

// Aceeași limită ca la importul din Open Library (import-openlibrary-cdump.js)
// și ca la scripts/book-enrichment/enrich_google.py, ca descrierile din catalog
// să rămână comparabile ca lungime indiferent de sursă.
const DESCRIPTION_MAX = 2000;

/**
 * Completează descrierea unei cărți din Google Books, la cerere.
 *
 * Catalogul are 3,68M de cărți importate din Open Library, dintre care 2,7M
 * fără descriere - dar userii au atins ~600. Îmbogățirea exhaustivă (vezi
 * scripts/book-enrichment/) rezolvă restanța; serviciul ăsta se ocupă de
 * fluxul invers, ca gaura să nu se redeschidă: în momentul în care cineva pune
 * o carte pe raft, cartea aia devine vizibilă și merită descriere.
 *
 * Apelat "fire and forget" - niciun răspuns HTTP nu așteaptă după el.
 */
@Injectable()
export class BookDescriptionService {
  private readonly logger = new Logger(BookDescriptionService.name);

  constructor(
    private prisma: PrismaService,
    private http: HttpService,
  ) {}

  /** Adaugă cheia Google Books API la un URL, dacă e setată (GOOGLE_BOOKS_API_KEY). */
  private withGoogleBooksKey(url: string): string {
    const key = process.env.GOOGLE_BOOKS_API_KEY;
    return key ? `${url}&key=${encodeURIComponent(key)}` : url;
  }

  private normalizeIsbn(value: string | null | undefined): string {
    return (value ?? '').replace(/[^0-9xX]/g, '').toUpperCase();
  }

  /**
   * Pornește completarea în fundal și returnează imediat.
   *
   * Orice eșec e înghițit intenționat: e o îmbunătățire oportunistă, nu o
   * parte din contractul endpointului care a declanșat-o.
   */
  scheduleBackfill(bookId: string): void {
    void this.backfillDescription(bookId).catch((error) => {
      this.logger.warn(`Backfill descriere eșuat pentru ${bookId}: ${error}`);
    });
  }

  async backfillDescription(bookId: string): Promise<boolean> {
    const book = await this.prisma.book.findUnique({
      where: { id: bookId },
      select: { id: true, isbn: true, description: true },
    });
    if (!book?.isbn || book.description) return false;

    const wanted = this.normalizeIsbn(book.isbn);
    if (!wanted) return false;

    const url = this.withGoogleBooksKey(
      `https://www.googleapis.com/books/v1/volumes?q=isbn:${encodeURIComponent(wanted)}`,
    );
    const { data } = await firstValueFrom(
      this.http.get<{ items?: GoogleVolume[] }>(url, { timeout: 5000 }),
    );

    // `q=isbn:` e o interogare, nu o potrivire exactă: Google poate întoarce
    // altă ediție sau altceva. Acceptăm doar volumul care chiar poartă ISBN-ul
    // cerut, la fel ca enrich_google.py - altfel am scrie descrierea altei cărți.
    const volume = (data.items ?? []).find((item) =>
      (item.volumeInfo?.industryIdentifiers ?? []).some(
        (ident) => this.normalizeIsbn(ident.identifier) === wanted,
      ),
    );
    const raw = volume?.volumeInfo?.description?.trim();
    if (!raw) return false;

    const description =
      raw.length > DESCRIPTION_MAX
        ? `${raw.slice(0, DESCRIPTION_MAX - 1).trimEnd()}…`
        : raw;

    // updateMany cu description: null în filtru: între SELECT-ul de mai sus și
    // scrierea asta altcineva (importul din scripts/) poate să fi completat deja
    // descrierea, iar noi n-o suprascriem niciodată.
    const { count } = await this.prisma.book.updateMany({
      where: { id: bookId, description: null },
      data: { description },
    });
    if (count > 0) {
      this.logger.log(`Descriere completată din Google Books pentru ${bookId}`);
    }
    return count > 0;
  }
}

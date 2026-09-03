import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Book, BookshelfStatus } from '@prisma/client';
import { parse } from 'csv-parse/sync';
import { PrismaService } from '../prisma/prisma.service';
import { BookDescriptionService } from '../books/book-description.service';
import { AddOwnedBookDto } from './dto/add-owned-book.dto';

export type BookshelfImportSource = 'goodreads' | 'storygraph';

// Un export Goodreads/StoryGraph rezonabil are câteva sute-mii de rânduri -
// atât cât să acopere biblioteci foarte mari, fără să lase cineva să
// trimită un fișier absurd de mare care ar bloca requestul mult timp.
const MAX_IMPORT_ROWS = 3000;

interface ParsedImportRow {
  title: string;
  author?: string;
  isbn?: string;
  publisher?: string;
  publishedYear?: number;
  pageCount?: number;
  status: BookshelfStatus | null;
}

@Injectable()
export class BookshelfService {
  constructor(
    private prisma: PrismaService,
    private bookDescriptions: BookDescriptionService,
  ) {}

  /**
   * Import "Read"/"Currently Reading"/"To Read" dintr-un export CSV
   * Goodreads sau StoryGraph - niciuna dintre platforme nu mai are un API
   * public (Goodreads l-a închis în 2020, StoryGraph n-a avut niciodată
   * unul), deci singura cale e userul să-și exporte propria bibliotecă și
   * s-o încarce aici. Cărțile se rezolvă/creează DOAR din datele deja
   * prezente în CSV (titlu/autor/ISBN/editură/an/pagini) - fără căutare
   * externă (Open Library/Google Books), ca importul unui fișier cu sute
   * de rânduri să nu rişte un timeout făcând sute de cereri HTTP secvențiale.
   */
  async importCsv(
    userId: string,
    source: BookshelfImportSource,
    buffer: Buffer,
  ) {
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
    if (rows.length > MAX_IMPORT_ROWS) {
      throw new BadRequestException(
        `Fișierul are prea multe rânduri (maxim ${MAX_IMPORT_ROWS})`,
      );
    }

    let imported = 0;
    let skipped = 0;
    for (const raw of rows) {
      const parsed =
        source === 'goodreads'
          ? this.parseGoodreadsRow(raw)
          : this.parseStoryGraphRow(raw);
      if (!parsed || !parsed.status) {
        skipped++;
        continue;
      }
      const book = await this.resolveOrCreateBook(parsed, source);
      await this.prisma.bookshelfEntry.upsert({
        where: { userId_bookId: { userId, bookId: book.id } },
        create: { userId, bookId: book.id, status: parsed.status },
        update: { status: parsed.status },
      });
      imported++;
    }

    return { imported, skipped, total: rows.length };
  }

  private async resolveOrCreateBook(
    parsed: ParsedImportRow,
    source: BookshelfImportSource,
  ) {
    const existing = parsed.isbn
      ? await this.prisma.book.findUnique({ where: { isbn: parsed.isbn } })
      : await this.prisma.book.findFirst({
          where: {
            title: { equals: parsed.title, mode: 'insensitive' },
            author: parsed.author
              ? { equals: parsed.author, mode: 'insensitive' }
              : undefined,
          },
        });
    if (existing) return existing;

    return this.prisma.book.create({
      data: {
        isbn: parsed.isbn,
        title: parsed.title,
        author: parsed.author,
        publisher: parsed.publisher,
        publishedYear: parsed.publishedYear,
        pageCount: parsed.pageCount,
        source: `${source}-import`,
      },
    });
  }

  private parseGoodreadsRow(
    row: Record<string, string>,
  ): ParsedImportRow | null {
    const title = row['Title']?.trim();
    if (!title) return null;
    return {
      title,
      author: row['Author']?.trim() || undefined,
      isbn: this.cleanIsbn(row['ISBN13']) ?? this.cleanIsbn(row['ISBN']),
      publisher: row['Publisher']?.trim() || undefined,
      publishedYear: this.parseYear(
        row['Year Published'] ?? row['Original Publication Year'],
      ),
      pageCount: this.parsePositiveInt(row['Number of Pages']),
      status: this.normalizeStatus(row['Exclusive Shelf']),
    };
  }

  private parseStoryGraphRow(
    row: Record<string, string>,
  ): ParsedImportRow | null {
    const title = row['Title']?.trim();
    if (!title) return null;
    return {
      title,
      author: row['Authors']?.split(',')[0]?.trim() || undefined,
      isbn: this.cleanIsbn(row['ISBN/UID']),
      status: this.normalizeStatus(row['Read Status']),
    };
  }

  /** Goodreads înfășoară ISBN-urile într-un pseudo-formulă Excel (ex. `="0439023483"`), ca Excel/Sheets să nu le trunchieze ca numere. */
  private cleanIsbn(raw: string | undefined): string | undefined {
    if (!raw) return undefined;
    const stripped = raw
      .replace(/^="?/, '')
      .replace(/"$/, '')
      .replace(/[-\s]/g, '');
    return /^[0-9Xx]{9,13}$/.test(stripped)
      ? stripped.toUpperCase()
      : undefined;
  }

  private normalizeStatus(raw: string | undefined): BookshelfStatus | null {
    const value = (raw ?? '').trim().toLowerCase().replace(/\s+/g, '-');
    if (value === 'read') return 'FINISHED';
    if (value === 'currently-reading') return 'READING';
    if (value === 'to-read') return 'WANT_TO_READ';
    return null;
  }

  private parseYear(raw: string | undefined): number | undefined {
    const n = parseInt((raw ?? '').trim(), 10);
    return Number.isFinite(n) && n > 1000 && n < 3000 ? n : undefined;
  }

  private parsePositiveInt(raw: string | undefined): number | undefined {
    const n = parseInt((raw ?? '').trim(), 10);
    return Number.isFinite(n) && n > 0 ? n : undefined;
  }

  async setStatus(
    userId: string,
    bookId: string,
    status: BookshelfStatus,
    owned?: boolean,
  ) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    const entry = await this.prisma.bookshelfEntry.upsert({
      where: { userId_bookId: { userId, bookId } },
      // `owned` absent din request => nu îl atingem pe o intrare existentă
      // (butonul de status de pe pagina cărții nu are de unde să știe dacă
      // userul are exemplarul în mână), dar la creare pornește de la false.
      create: { userId, bookId, status, owned: owned ?? false },
      update: { status, ...(owned === undefined ? {} : { owned }) },
      include: { book: true },
    });

    // Din momentul asta cartea e vizibila pentru cineva, deci merita descriere.
    // Fire and forget: raspunsul nu asteapta dupa Google Books.
    if (!book.description) {
      this.bookDescriptions.scheduleBackfill(bookId);
    }

    return entry;
  }

  async removeFromShelf(userId: string, bookId: string) {
    await this.prisma.bookshelfEntry.deleteMany({ where: { userId, bookId } });
    return { message: 'Cartea a fost eliminată din raft' };
  }

  async getStatusForBook(userId: string, bookId: string) {
    const entry = await this.prisma.bookshelfEntry.findUnique({
      where: { userId_bookId: { userId, bookId } },
    });
    return { status: entry?.status ?? null };
  }

  /**
   * „Add to shelf" - cartea ajunge în raftul personal ca deținută, FĂRĂ să
   * creeze un anunț. Reutilizează exact aceeași rezolvare de carte ca importul
   * CSV (dedupe pe ISBN, altfel titlu+autor), ca să nu umplem catalogul cu
   * duplicate pentru titluri deja cunoscute.
   */
  async addOwnedBook(userId: string, dto: AddOwnedBookDto) {
    // Validăm ÎNAINTE de orice scriere: altfel un procent fără total lăsa în
    // urmă o carte nouă în catalog și o intrare de raft, apoi arunca 400 -
    // userul vedea eroare, dar cartea îi apărea totuși pe raft.
    if (dto.currentPage == null && dto.percentRead != null) {
      const knownTotal = dto.totalPages ?? (await this.lookupPageCount(dto));
      if (knownTotal == null) {
        throw new BadRequestException(
          'Ca să salvăm un procent, avem nevoie de numărul total de pagini',
        );
      }
    }

    const book = await this.resolveOrCreateBookForShelf(dto);

    const entry = await this.prisma.bookshelfEntry.upsert({
      where: { userId_bookId: { userId, bookId: book.id } },
      create: {
        userId,
        bookId: book.id,
        status: dto.status ?? 'READING',
        owned: dto.owned ?? true,
      },
      update: {
        status: dto.status ?? 'READING',
        owned: dto.owned ?? true,
      },
      include: { book: true },
    });

    if (!book.description) {
      this.bookDescriptions.scheduleBackfill(book.id);
    }

    const progress = await this.saveProgress(userId, book, dto);
    return { ...entry, progress };
  }

  /**
   * Progresul la citit, așa cum vine din formularul de „add to shelf":
   * pagini SAU procent, plus numărul total de pagini al ediției proprii.
   * Procentul se convertește imediat în pagini - `ReadingProgress.currentPage`
   * rămâne singura sursă de adevăr, ca bara de progres să arate la fel
   * indiferent cum a fost introdus.
   */
  private async saveProgress(
    userId: string,
    book: Book,
    dto: AddOwnedBookDto,
  ) {
    const total = dto.totalPages ?? book.pageCount ?? null;

    let currentPage = dto.currentPage ?? null;
    if (currentPage == null && dto.percentRead != null) {
      if (total == null) {
        throw new BadRequestException(
          'Ca să salvăm un procent, avem nevoie de numărul total de pagini',
        );
      }
      currentPage = Math.round((total * dto.percentRead) / 100);
    }
    // Nici pagini, nici procent, nici pagini de ediție => n-avem ce salva.
    if (currentPage == null && dto.totalPages == null) return null;
    currentPage ??= 0;

    if (total != null && currentPage > total) {
      throw new BadRequestException(
        `Pagina nu poate depăși numărul total de pagini (${total})`,
      );
    }

    return this.prisma.readingProgress.upsert({
      where: { userId_bookId: { userId, bookId: book.id } },
      create: {
        userId,
        bookId: book.id,
        currentPage,
        totalPages: dto.totalPages ?? null,
      },
      update: {
        currentPage,
        ...(dto.totalPages == null ? {} : { totalPages: dto.totalPages }),
      },
    });
  }

  /// Câte pagini știm deja despre carte, fără s-o creăm - folosit doar la
  /// validarea de mai sus, ca un procent trimis pentru o carte deja din catalog
  /// să fie acceptat chiar dacă userul n-a completat totalul manual.
  private async lookupPageCount(dto: AddOwnedBookDto) {
    const isbn = this.cleanIsbn(dto.isbn);
    const existing = isbn
      ? await this.prisma.book.findUnique({ where: { isbn } })
      : await this.prisma.book.findFirst({
          where: {
            title: { equals: dto.title, mode: 'insensitive' },
            author: dto.author
              ? { equals: dto.author, mode: 'insensitive' }
              : undefined,
          },
        });
    return existing?.pageCount ?? null;
  }

  private async resolveOrCreateBookForShelf(dto: AddOwnedBookDto) {
    const isbn = this.cleanIsbn(dto.isbn);
    const existing = isbn
      ? await this.prisma.book.findUnique({ where: { isbn } })
      : await this.prisma.book.findFirst({
          where: {
            title: { equals: dto.title, mode: 'insensitive' },
            author: dto.author
              ? { equals: dto.author, mode: 'insensitive' }
              : undefined,
          },
        });
    if (existing) return existing;

    return this.prisma.book.create({
      data: {
        isbn,
        title: dto.title,
        author: dto.author,
        coverUrl: dto.coverUrl,
        genre: dto.genre,
        publisher: dto.publisher,
        publishedYear: dto.publishedYear,
        // `totalPages` din DTO e paginile EDIȚIEI userului și stă pe
        // ReadingProgress; pe Book îl punem doar când creăm cartea acum, ca
        // primă valoare cunoscută pentru catalog.
        pageCount: dto.totalPages,
        source: 'shelf-manual',
      },
    });
  }

  /**
   * Cărțile pe care userul le DEȚINE - prim-planul din My Shelf.
   *
   * O carte care are deja un anunț activ (UserBook neșters) iese de aici cât
   * timp NU e în curs de citire: apare oricum în grila de listări de dedesubt,
   * ar fi dublată. Cea în curs de citire rămâne totuși, marcată `listed`:
   * progresul la citit nu se vede nicăieri în grila de listări, deci
   * filtrarea ei o făcea să dispară complet din My Shelf imediat ce userul o
   * și lista - exact bugul raportat („am adăugat o carte ca fiind în curs de
   * citire și nu apare deloc").
   */
  async getOwnedShelf(userId: string) {
    const [entries, listed, progress] = await Promise.all([
      this.prisma.bookshelfEntry.findMany({
        where: { userId, owned: true },
        include: { book: true },
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.userBook.findMany({
        where: { userId, deletedAt: null },
        select: { bookId: true },
      }),
      this.prisma.readingProgress.findMany({ where: { userId } }),
    ]);

    const listedBookIds = new Set(listed.map((l) => l.bookId));
    const progressByBook = new Map(progress.map((p) => [p.bookId, p]));

    return entries
      .filter((e) => e.status === 'READING' || !listedBookIds.has(e.bookId))
      .map((e) => {
        const p = progressByBook.get(e.bookId);
        return {
          bookId: e.bookId,
          status: e.status,
          book: e.book,
          currentPage: p?.currentPage ?? 0,
          totalPages: p?.totalPages ?? e.book.pageCount ?? null,
          // Are deja anunț: cardul ascunde îndemnul „listeaz-o" și pune în
          // loc o etichetă, ca să nu pară că mai e ceva de făcut cu ea.
          listed: listedBookIds.has(e.bookId),
          updatedAt: e.updatedAt,
        };
      });
  }

  async getMyShelf(userId: string) {
    const entries = await this.prisma.bookshelfEntry.findMany({
      where: { userId },
      include: { book: true },
      orderBy: { updatedAt: 'desc' },
    });
    return this.groupByStatus(entries);
  }

  /**
   * Raftul public al unui user - folosit de profile.service.ts la
   * afișarea profilului public, alături de "Shared" (derivat separat din
   * UserBook, nu stocat aici - vezi comentariul de pe BookshelfEntry).
   */
  async getPublicShelf(userId: string) {
    const entries = await this.prisma.bookshelfEntry.findMany({
      where: { userId },
      include: { book: true },
      orderBy: { updatedAt: 'desc' },
    });
    return this.groupByStatus(entries);
  }

  /**
   * Top 5 genuri din preferințele userului, pentru graficul radar din My
   * Shelf: raft (Reading/Want to Read/Finished) + cărți listate la schimb +
   * wishlist, ca să reflecte toate genurile care îl interesează, nu doar ce
   * a bifat explicit pe raft. Nu pornim de la scorurile Book Match, derivate
   * din swipe-uri - un user poate să nu fi jucat deloc Book Match, dar tot
   * are un raft/wishlist - de asta e o interogare separată aici, nu o
   * reutilizare a userGenreScore.
   */
  async getGenreDistribution(userId: string) {
    const [shelfEntries, listedBooks, wishlistItems] = await Promise.all([
      this.prisma.bookshelfEntry.findMany({
        where: { userId },
        select: { book: { select: { genre: true } } },
      }),
      this.prisma.userBook.findMany({
        where: { userId, deletedAt: null },
        select: { book: { select: { genre: true } } },
      }),
      this.prisma.wishlistItem.findMany({
        where: { userId },
        select: { book: { select: { genre: true } } },
      }),
    ]);

    const counts = new Map<string, number>();
    for (const entry of [...shelfEntries, ...listedBooks, ...wishlistItems]) {
      const genre = entry.book.genre;
      if (!genre) continue;
      counts.set(genre, (counts.get(genre) ?? 0) + 1);
    }

    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([genre, count]) => ({ genre, count }));
  }

  private groupByStatus(entries: { status: BookshelfStatus; book: Book }[]) {
    return {
      reading: entries.filter((e) => e.status === 'READING').map((e) => e.book),
      wantToRead: entries
        .filter((e) => e.status === 'WANT_TO_READ')
        .map((e) => e.book),
      finished: entries
        .filter((e) => e.status === 'FINISHED')
        .map((e) => e.book),
    };
  }
}

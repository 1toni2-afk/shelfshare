import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Book, BookshelfStatus } from '@prisma/client';
import { parse } from 'csv-parse/sync';
import { PrismaService } from '../prisma/prisma.service';

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
  constructor(private prisma: PrismaService) {}

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
  async importCsv(userId: string, source: BookshelfImportSource, buffer: Buffer) {
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
      throw new BadRequestException(`Fișierul are prea multe rânduri (maxim ${MAX_IMPORT_ROWS})`);
    }

    const parseRow = source === 'goodreads' ? this.parseGoodreadsRow : this.parseStoryGraphRow;

    let imported = 0;
    let skipped = 0;
    for (const raw of rows) {
      const parsed = parseRow.call(this, raw);
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

  private async resolveOrCreateBook(parsed: ParsedImportRow, source: BookshelfImportSource) {
    const existing = parsed.isbn
      ? await this.prisma.book.findUnique({ where: { isbn: parsed.isbn } })
      : await this.prisma.book.findFirst({
          where: {
            title: { equals: parsed.title, mode: 'insensitive' },
            author: parsed.author ? { equals: parsed.author, mode: 'insensitive' } : undefined,
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

  private parseGoodreadsRow(row: Record<string, string>): ParsedImportRow | null {
    const title = row['Title']?.trim();
    if (!title) return null;
    return {
      title,
      author: row['Author']?.trim() || undefined,
      isbn: this.cleanIsbn(row['ISBN13']) ?? this.cleanIsbn(row['ISBN']),
      publisher: row['Publisher']?.trim() || undefined,
      publishedYear: this.parseYear(row['Year Published'] ?? row['Original Publication Year']),
      pageCount: this.parsePositiveInt(row['Number of Pages']),
      status: this.normalizeStatus(row['Exclusive Shelf']),
    };
  }

  private parseStoryGraphRow(row: Record<string, string>): ParsedImportRow | null {
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
    return /^[0-9Xx]{9,13}$/.test(stripped) ? stripped.toUpperCase() : undefined;
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

  async setStatus(userId: string, bookId: string, status: BookshelfStatus) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    return this.prisma.bookshelfEntry.upsert({
      where: { userId_bookId: { userId, bookId } },
      create: { userId, bookId, status },
      update: { status },
      include: { book: true },
    });
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

  private groupByStatus(entries: { status: BookshelfStatus; book: Book }[]) {
    return {
      reading: entries.filter((e) => e.status === 'READING').map((e) => e.book),
      wantToRead: entries.filter((e) => e.status === 'WANT_TO_READ').map((e) => e.book),
      finished: entries.filter((e) => e.status === 'FINISHED').map((e) => e.book),
    };
  }
}

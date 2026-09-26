import { Injectable, Logger } from '@nestjs/common';
import type { Book } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/** Câte rânduri candidate aduce prefiltrul indexat înainte de comparația exactă. */
const CANDIDATE_LIMIT = 50;

/**
 * Leagă un titlu tastat (fără ISBN și fără `bookId` ales din autocomplete) de
 * o carte care EXISTĂ deja în catalog, în loc să creeze încă un rând „manual".
 *
 * Fără asta, orice carte adăugată fără ISBN devenea o carte nouă în catalog,
 * chiar dacă titlul era deja acolo: anunțul nu apărea pe pagina operei, Book
 * Match și căutarea îl vedeau ca pe altă carte, iar coperta curată nu se lega.
 *
 * Potrivirea e strictă, ca să nu lipim anunțul de o carte greșită: titlul
 * trebuie să fie IDENTIC după normalizare (minuscule, fără diacritice, doar
 * litere și cifre), iar când userul a dat și autorul, și autorul trebuie să
 * se potrivească. Rândurile curate câștigă, apoi cele mai populare.
 *
 * Interogarea trece întâi prin indexul FTS (`books_search_fts_idx`, aceeași
 * expresie ca în BooksService.searchCatalog) și abia apoi compară exact, în
 * cod: o egalitate pe o expresie neindexată ar fi un seq scan pe ~3,7M rânduri.
 */
@Injectable()
export class CatalogMatchService {
  private readonly logger = new Logger(CatalogMatchService.name);

  constructor(private prisma: PrismaService) {}

  /** Minuscule, fără diacritice, cuvintele despărțite de un singur spațiu. */
  static normalize(value: string | null | undefined): string {
    return (value ?? '')
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .toLowerCase()
      .split(/[^a-z0-9]+/)
      .filter((term) => term.length > 0)
      .join(' ');
  }

  /**
   * Autorul se potrivește dacă numele normalizate coincid, sau dacă au același
   * nume de familie (ultimul cuvânt) - „J.R.R. Tolkien" și „John Ronald Reuel
   * Tolkien" sunt același autor, scrise diferit de surse diferite.
   */
  private static authorMatches(wanted: string, candidate: string | null): boolean {
    const a = CatalogMatchService.normalize(wanted);
    const b = CatalogMatchService.normalize(candidate);
    if (!a || !b) return false;
    if (a === b) return true;
    const lastA = a.split(' ').at(-1)!;
    const lastB = b.split(' ').at(-1)!;
    return lastA.length > 2 && lastA === lastB;
  }

  async findByTitle(title: string, author?: string | null): Promise<Book | null> {
    const wantedTitle = CatalogMatchService.normalize(title);
    if (!wantedTitle) return null;

    const tsquery = wantedTitle.split(' ').join(' & ');
    let candidates: Book[];
    try {
      // Lot mărginit întâi (ca în searchCatalog): un titlu scurt și comun
      // potrivește zeci de mii de rânduri, iar sortarea lor pe toate ar fi
      // lentă. În lot, titlurile de lungime apropiată de cea căutată vin
      // primele - sunt singurele care pot fi potriviri exacte.
      candidates = await this.prisma.$queryRaw<Book[]>`
        WITH matched AS (
          SELECT *
          FROM "books"
          WHERE to_tsvector(
                  'simple',
                  immutable_unaccent(coalesce("title", '') || ' ' || coalesce("author", ''))
                ) @@ to_tsquery('simple', ${tsquery})
          ORDER BY ("curatedAt" IS NOT NULL) DESC
          LIMIT 2000
        )
        SELECT *
        FROM matched
        ORDER BY
          ("curatedAt" IS NOT NULL) DESC,
          abs(length(title) - ${title.trim().length}) ASC,
          COALESCE("popularityScore", 0) DESC
        LIMIT ${CANDIDATE_LIMIT}
      `;
    } catch (error) {
      // Fără migrarea books_diacritic_search funcția nu există. Nu blocăm
      // adăugarea cărții: se creează ca înainte, doar nelegată.
      this.logger.warn(`Potrivirea în catalog a eșuat: ${error}`);
      return null;
    }

    const sameTitle = candidates.filter(
      (book) => CatalogMatchService.normalize(book.title) === wantedTitle,
    );
    if (sameTitle.length === 0) return null;

    if (author?.trim()) {
      return sameTitle.find((book) => CatalogMatchService.authorMatches(author, book.author)) ?? null;
    }
    // Fără autor, titlul singur e ambiguu când mai mulți autori au o carte
    // cu același nume („Inferno", „Emma"). Legăm doar dacă e un singur autor.
    const authors = new Set(sameTitle.map((book) => CatalogMatchService.normalize(book.author)));
    return authors.size === 1 ? sameTitle[0] : null;
  }
}

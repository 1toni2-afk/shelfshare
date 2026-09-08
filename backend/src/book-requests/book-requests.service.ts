import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import {
  BookRequest,
  BookRequestStatus,
  NotificationType,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BooksService } from '../books/books.service';
import { BookLookupService } from '../books/book-lookup.service';
import type { ExternalBookResult } from '../books/types/external-book-result';
import { CreateBookRequestDto } from './dto/create-book-request.dto';
import {
  ResolveBookRequestDto,
  ResolvedBookDto,
} from './dto/resolve-book-request.dto';

/// Cereri active (PENDING) per user. Plasă de siguranță, nu o limită pe care
/// s-o atingă cineva real: fiecare cerere e căutată în fiecare noapte, la
/// providerii externi, până e găsită.
const MAX_ACTIVE_REQUESTS_PER_USER = 20;

/// După atâtea nopți fără rezultat, cererea iese din coadă (trece în
/// NOT_FOUND) - nu se șterge: userul vede ce s-a ales de cererea lui, iar în
/// panoul de admin rămâne pe filtrul „Negăsite".
///
/// Trei nopți înseamnă că titlul a trecut deja prin TOATE sursele de câteva
/// ori - catalogul propriu, Google Books, Open Library, plus cele patru
/// librării românești. Ce nu apare în trei treceri nu apare nici în
/// paisprezece: e fie scris greșit, fie chiar nu există nicăieri online.
const MAX_RESOLVE_ATTEMPTS = 3;

/// Câte cereri ia o rulare de noapte. Fiecare înseamnă până la două apeluri
/// externe (Google Books + Open Library), deci lotul e ținut mic în mod
/// deliberat - restul așteaptă noaptea următoare, în aceeași ordine.
const NIGHTLY_BATCH_SIZE = 60;

/// Un rând din coada de noapte: cererea + câți useri DISTINCȚI au cerut
/// același titlu (vezi `queue`).
export interface QueuedBookRequest extends BookRequest {
  demand: number;
}

@Injectable()
export class BookRequestsService {
  private readonly logger = new Logger(BookRequestsService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private books: BooksService,
    private lookup: BookLookupService,
  ) {}

  /**
   * Cheia de deduplicare: titlu + autor fără diacritice, minuscule, un singur
   * spațiu. Aceeași normalizare ca la căutarea în catalog (ă→a, ș→s, ț→t), ca
   * „Stăpânul Inelelor" și „Stapanul inelelor" să fie aceeași cerere.
   */
  static normalizeKey(title: string, author?: string | null): string {
    const clean = (value: string) =>
      value
        .normalize('NFD')
        .replace(/\p{Diacritic}/gu, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
    const normalizedTitle = clean(title);
    const normalizedAuthor = author ? clean(author) : '';
    return normalizedAuthor
      ? `${normalizedTitle}|${normalizedAuthor}`
      : normalizedTitle;
  }

  private normalize(title: string, author?: string | null) {
    return BookRequestsService.normalizeKey(title, author);
  }

  /**
   * Formularul „nu găsesc cartea". Înainte de a crea rândul, mai încercăm o
   * dată în catalogul propriu: userul scrie aici titlul STRUCTURAT (titlu
   * separat de autor), pe când căutarea din care a venit era un singur text
   * liber - se întâmplă să găsim acum ce n-am găsit atunci. Dacă o găsim,
   * întoarcem cartea direct și nu mai creăm nicio cerere.
   */
  async create(userId: string, dto: CreateBookRequestDto) {
    const title = dto.title.trim();
    const author = dto.author?.trim() || null;
    const normalizedKey = this.normalize(title, author);
    if (!normalizedKey.replace(/[|\s]/g, '')) {
      throw new BadRequestException('Titlul cărții este obligatoriu');
    }

    const immediate = await this.searchCatalogFor(title, author);
    if (immediate) {
      const book = await this.ensureBook(immediate, false);
      return { status: 'found' as const, request: null, book };
    }

    const existing = await this.prisma.bookRequest.findUnique({
      where: { userId_normalizedKey: { userId, normalizedKey } },
    });
    if (existing) {
      // Retrimiterea aceleiași cereri nu e o eroare pentru user - o reactivăm
      // (poate o anulase) și îi arătăm rândul existent. O cerere deja
      // rezolvată rămâne rezolvată: cartea e în catalog, nu mai are ce căuta
      // în coada de noapte.
      const request = await this.prisma.bookRequest.update({
        where: { id: existing.id },
        data:
          existing.status === BookRequestStatus.FULFILLED
            ? { note: dto.note?.trim() || existing.note }
            : {
                status: BookRequestStatus.PENDING,
                attempts: 0,
                note: dto.note?.trim() || existing.note,
                isbn: dto.isbn?.trim() || existing.isbn,
              },
        include: { book: true },
      });
      return { status: 'pending' as const, request, book: request.book };
    }

    const active = await this.prisma.bookRequest.count({
      where: { userId, status: BookRequestStatus.PENDING },
    });
    if (active >= MAX_ACTIVE_REQUESTS_PER_USER) {
      throw new BadRequestException(
        `Poți avea cel mult ${MAX_ACTIVE_REQUESTS_PER_USER} cereri de carte în așteptare`,
      );
    }

    const request = await this.prisma.bookRequest.create({
      data: {
        userId,
        title,
        author,
        isbn: dto.isbn?.trim() || null,
        note: dto.note?.trim() || null,
        normalizedKey,
      },
      include: { book: true },
    });
    return { status: 'pending' as const, request, book: null };
  }

  getMine(userId: string) {
    return this.prisma.bookRequest.findMany({
      where: { userId },
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      include: { book: true },
    });
  }

  async cancel(userId: string, id: string) {
    const request = await this.prisma.bookRequest.findUnique({ where: { id } });
    if (!request || request.userId !== userId) {
      throw new NotFoundException('Cererea nu a fost găsită');
    }
    await this.prisma.bookRequest.update({
      where: { id },
      data: { status: BookRequestStatus.CANCELLED },
    });
    return { message: 'Cerere anulată' };
  }

  /**
   * Coada de noapte, în ordinea în care merită căutate: întâi titlurile cerute
   * de cei mai mulți oameni, apoi cele cu cele mai puține încercări (o cerere
   * nouă nu așteaptă după una pe care am ratat-o deja de zece ori), apoi cele
   * mai vechi.
   *
   * `demand` numără userii DISTINCȚI cu aceeași `normalizedKey`, nu rândurile:
   * unicitatea (userId, normalizedKey) garantează deja un rând per om, dar
   * numărul explicit e ce trimitem mai departe scraperelor, care își aleg
   * singure cât timp alocă unui titlu.
   */
  queue(limit = NIGHTLY_BATCH_SIZE): Promise<QueuedBookRequest[]> {
    return this.prisma.$queryRaw<QueuedBookRequest[]>`
      SELECT r.*,
             (
               SELECT COUNT(DISTINCT p."userId")::int
               FROM "book_requests" p
               WHERE p."normalizedKey" = r."normalizedKey"
                 AND p."status" = 'PENDING'
             ) AS demand
      FROM "book_requests" r
      WHERE r."status" = 'PENDING'
      ORDER BY demand DESC, r."attempts" ASC, r."createdAt" ASC
      LIMIT ${limit}
    `;
  }

  /**
   * Rulează în fiecare noapte la 02:30, înaintea scraperelor de magazine (care
   * pornesc separat, pe gazdă - vezi
   * scripts/book-requests/nightly_book_requests.py): sursele de aici sunt doar
   * cele accesibile din backend - catalogul propriu, Google Books, Open
   * Library. Ce rămâne negăsit trece prin librăriile românești.
   *
   * Secvențial, nu în paralel: providerii externi sunt limitați la număr de
   * cereri, iar o coadă de 60 de titluri nu are niciun motiv să fie rapidă.
   */
  @Cron('30 2 * * *')
  async resolvePendingRequests(): Promise<void> {
    const pending = await this.queue();
    if (pending.length === 0) return;

    this.logger.log(
      `Căutare de noapte pentru ${pending.length} cereri de carte`,
    );
    let found = 0;
    for (const request of pending) {
      try {
        const resolved = await this.attemptResolve(request);
        if (resolved) found += 1;
      } catch (error) {
        this.logger.warn(`Cererea ${request.id} a eșuat: ${error}`);
      }
    }
    this.logger.log(
      `Căutare de noapte terminată: ${found}/${pending.length} cereri rezolvate`,
    );
  }

  /** O singură cerere, prin toate sursele disponibile din backend. */
  private async attemptResolve(request: BookRequest): Promise<boolean> {
    const match =
      (await this.searchCatalogFor(request.title, request.author)) ??
      (await this.searchExternalFor(request));

    if (!match) {
      await this.recordFailedAttempt(request);
      return false;
    }

    const book = await this.ensureBook(match, false);
    await this.fulfill(request.normalizedKey, book.id, match.source);
    return true;
  }

  /** Încercare fără rezultat: crește contorul, iar la plafon oprește cererea. */
  async recordFailedAttempt(request: Pick<BookRequest, 'id' | 'attempts'>) {
    const attempts = request.attempts + 1;
    await this.prisma.bookRequest.update({
      where: { id: request.id },
      data: {
        attempts,
        lastAttemptAt: new Date(),
        status:
          attempts >= MAX_RESOLVE_ATTEMPTS
            ? BookRequestStatus.NOT_FOUND
            : BookRequestStatus.PENDING,
      },
    });
  }

  /**
   * Marchează drept găsite TOATE cererile în așteptare pentru același titlu,
   * indiferent de cine le-a făcut, și îi anunță pe toți: cartea intră o
   * singură dată în catalog, deci n-are rost s-o mai caute nimeni pentru
   * ceilalți solicitanți.
   */
  async fulfill(normalizedKey: string, bookId: string, source: string) {
    const requests = await this.prisma.bookRequest.findMany({
      where: { normalizedKey, status: BookRequestStatus.PENDING },
    });
    if (requests.length === 0) return 0;

    await this.prisma.bookRequest.updateMany({
      where: { id: { in: requests.map((r) => r.id) } },
      data: {
        status: BookRequestStatus.FULFILLED,
        bookId,
        resolvedSource: source,
        fulfilledAt: new Date(),
        lastAttemptAt: new Date(),
      },
    });

    for (const request of requests) {
      await this.notifications
        .create(
          request.userId,
          NotificationType.BOOK_REQUEST_FOUND,
          `Am găsit „${request.title}" - e acum în catalog`,
          { bookId, requestId: request.id },
        )
        .catch((error) => {
          this.logger.warn(`Notificarea pentru ${request.id} a eșuat: ${error}`);
        });
    }
    return requests.length;
  }

  /**
   * Răspunsul unui scraper de magazin (vezi ResolveBookRequestDto): fie cartea
   * găsită, fie „am căutat, n-am găsit".
   */
  async resolveFromWorker(dto: ResolveBookRequestDto) {
    const request = await this.prisma.bookRequest.findUnique({
      where: { id: dto.requestId },
    });
    if (!request) throw new NotFoundException('Cererea nu a fost găsită');

    if (!dto.book) {
      await this.recordFailedAttempt(request);
      return { status: 'not_found' as const };
    }

    const book = await this.ensureBook(
      this.toExternalResult(dto.book),
      dto.curated === true,
    );
    const notified = await this.fulfill(
      request.normalizedKey,
      book.id,
      dto.source,
    );
    return { status: 'fulfilled' as const, bookId: book.id, notified };
  }

  private toExternalResult(book: ResolvedBookDto): ExternalBookResult {
    return {
      isbn: book.isbn?.replace(/[-\s]/g, '') || null,
      title: book.title,
      author: book.author ?? null,
      description: book.description ?? null,
      coverUrl: book.coverUrl ?? null,
      publisher: book.publisher ?? null,
      publishedYear: book.publishedYear ?? null,
      pageCount: book.pageCount ?? null,
      language: book.language ?? null,
      genre: book.genre ?? null,
      subjects: [],
      source: 'catalog',
    };
  }

  /** Catalogul propriu, cu aceeași căutare ca autocomplete-ul. */
  private async searchCatalogFor(title: string, author: string | null) {
    const query = author ? `${title} ${author}` : title;
    const results = await this.books
      .searchCatalog(query, 8)
      .catch((error): ExternalBookResult[] => {
        this.logger.warn(`Căutarea în catalog a eșuat: ${error}`);
        return [];
      });
    return this.pickMatch(results, title, author);
  }

  /** Google Books + Open Library, prin același lookup ca restul aplicației. */
  private async searchExternalFor(request: BookRequest) {
    if (request.isbn) {
      const byIsbn = await this.lookup
        .lookupByIsbn(request.isbn.replace(/[-\s]/g, ''))
        .catch(() => null);
      if (byIsbn) return byIsbn;
    }
    const results = await this.lookup
      .searchByTitle(request.title, { author: request.author })
      .catch((): ExternalBookResult[] => []);
    return this.pickMatch(results, request.title, request.author);
  }

  /**
   * Filtrul care ține catalogul curat: acceptăm un rezultat DOAR dacă titlul
   * lui normalizat e identic cu cel cerut sau începe cu el (ediții de tipul
   * „Titlu. Volumul II"), iar dacă userul a dat autorul, numele lui trebuie să
   * apară în autorul rezultatului.
   *
   * Fără asta, „o carte de-a lui Eco despre nu-mai-știu-ce" ar fi „rezolvată"
   * cu primul rezultat aproximativ de la Google Books, iar userul ar primi
   * notificare pentru o carte pe care n-a cerut-o.
   */
  private pickMatch(
    results: ExternalBookResult[],
    title: string,
    author: string | null,
  ): ExternalBookResult | null {
    const wantedTitle = this.normalize(title);
    const wantedAuthor = author ? this.normalize(author) : null;

    return (
      results.find((result) => {
        const resultTitle = this.normalize(result.title);
        const titleOk =
          resultTitle === wantedTitle || resultTitle.startsWith(wantedTitle);
        if (!titleOk) return false;
        if (!wantedAuthor) return true;
        if (!result.author) return false;
        const resultAuthor = this.normalize(result.author);
        return (
          resultAuthor.includes(wantedAuthor) ||
          wantedAuthor.includes(resultAuthor)
        );
      }) ?? null
    );
  }

  /**
   * Rândul din `books` pentru cartea găsită: refolosit dacă îl avem deja (pe
   * ISBN, altfel pe titlu+autor), creat altfel. Deduplicarea contează aici mai
   * mult decât oriunde - o cerere rezolvată cu un rând nou pentru o carte care
   * există deja ar împărți anunțurile între două opere identice.
   */
  private async ensureBook(result: ExternalBookResult, curated: boolean) {
    if (result.bookId) {
      const known = await this.prisma.book.findUnique({
        where: { id: result.bookId },
      });
      if (known) return known;
    }

    const isbn = result.isbn?.replace(/[-\s]/g, '') || null;
    if (isbn) {
      const existing = await this.prisma.book.findUnique({ where: { isbn } });
      if (existing) return existing;
    } else {
      const existing = await this.prisma.book.findFirst({
        where: {
          title: { equals: result.title, mode: 'insensitive' },
          author: result.author
            ? { equals: result.author, mode: 'insensitive' }
            : null,
        },
      });
      if (existing) return existing;
    }

    return this.prisma.book.create({
      data: {
        isbn,
        title: result.title,
        author: result.author,
        description: result.description,
        coverUrl: result.coverUrl,
        publisher: result.publisher,
        publishedYear: result.publishedYear,
        pageCount: result.pageCount,
        language: result.language,
        genre: result.genre,
        source: 'book_request',
        // Titlurile venite de la librăriile românești sunt de aceeași calitate
        // cu catalogul scrapuit manual, deci intră în el: căutarea le preferă
        // în fața rezultatelor externe (vezi Book.curatedAt).
        curatedAt: curated ? new Date() : null,
      },
    });
  }

  /**
   * Panoul de admin: cererile, cu filtrare pe status.
   *
   * `demand` (câți useri DISTINCȚI așteaptă același titlu) vine pe fiecare
   * rând fiindcă e chiar cheia după care se ordonează căutarea de noapte -
   * fără el, panoul ar arăta o listă în care nu se vede ce se caută primul.
   * Se calculează dintr-un singur `groupBy` peste cererile în așteptare, nu
   * cu câte o interogare per rând.
   */
  async listForAdmin(status?: BookRequestStatus, limit = 100) {
    const requests = await this.prisma.bookRequest.findMany({
      where: status ? { status } : undefined,
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 500),
      include: {
        book: { select: { id: true, title: true, author: true } },
        user: { select: { id: true, email: true, name: true } },
      },
    });
    if (requests.length === 0) return [];

    const pendingByKey = await this.prisma.bookRequest.groupBy({
      by: ['normalizedKey'],
      where: {
        status: BookRequestStatus.PENDING,
        normalizedKey: { in: requests.map((r) => r.normalizedKey) },
      },
      _count: { userId: true },
    });
    const demandByKey = new Map(
      pendingByKey.map((row) => [row.normalizedKey, row._count.userId]),
    );

    return requests.map((request) => ({
      ...request,
      demand: demandByKey.get(request.normalizedKey) ?? 0,
    }));
  }
}

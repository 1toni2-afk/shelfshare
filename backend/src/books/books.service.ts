import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
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
  constructor(
    private prisma: PrismaService,
    private lookup: BookLookupService,
    private storage: StorageService,
    private wishlist: WishlistService,
    private follow: FollowService,
    private notifications: NotificationsService,
  ) {}

  async searchExternal(query: string) {
    this.logSearch(query);
    return this.lookup.searchByTitle(query);
  }

  async searchLibrary(filters: SearchLibraryDto) {
    if (filters.title) this.logSearch(filters.title);

    const where: Prisma.UserBookWhereInput = {
      availableForSwap: filters.availableOnly === 'false' ? undefined : true,
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
        include: { book: true, user: { select: OWNER_SELECT } },
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

    const orderBy: Prisma.UserBookOrderByWithRelationInput =
      filters.sort === 'mostViewed'
        ? { viewCount: 'desc' }
        : { createdAt: 'desc' };

    const [items, total] = await Promise.all([
      this.prisma.userBook.findMany({
        where,
        include: { book: true, user: { select: OWNER_SELECT } },
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
    const userBook = await this.prisma.userBook.create({
      data: {
        userId,
        bookId: book.id,
        condition: dto.condition,
        language: dto.language,
        edition: dto.edition,
        isHardcover: dto.isHardcover ?? false,
        isForSale: false,
      },
      include: { book: true },
    });

    this.wishlist.notifyWishlistedUsers(book.id, userId).catch(() => {});
    this.follow.notifyFollowersOfNewBook(userId, book.title).catch(() => {});
    this.notifyNearbyUsers(userId, book.title).catch(() => {});
    awardXp(this.prisma, userId, XP_BOOK_LISTED);

    return userBook;
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

  private async findOrCreateBook(dto: AddBookDto) {
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
          source: 'manual',
          referencePrice: referencePrice?.price,
          referencePriceCurrency: referencePrice?.currency,
        },
      });
    }

    if (!dto.title) {
      throw new BadRequestException('Titlul este obligatoriu dacă nu dai ISBN');
    }
    return this.prisma.book.create({
      data: {
        title: dto.title,
        author: dto.author,
        source: 'manual',
      },
    });
  }

  async getMyLibrary(userId: string) {
    const items = await this.prisma.userBook.findMany({
      where: { userId },
      include: { book: true },
      orderBy: { createdAt: 'desc' },
    });
    return items.map((i) => this.toPublicPhotos(i));
  }

  async getUserBook(userBookId: string) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      include: { book: true, user: { select: OWNER_SELECT } },
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
        genre: query
          ? { contains: query, mode: 'insensitive' }
          : { not: null },
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

    const books = await this.prisma.book.findMany({ where: { id: { in: topIds } } });
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
      authorCounts.set(book.author!, (authorCounts.get(book.author!) ?? 0) + count);
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
  async getTrendingBooks() {
    const since = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000);
    const views = await this.prisma.bookView.findMany({
      where: { createdAt: { gte: since } },
      select: { userBook: { select: { bookId: true } } },
    });

    const counts = new Map<string, number>();
    for (const view of views) {
      const id = view.userBook.bookId;
      counts.set(id, (counts.get(id) ?? 0) + 1);
    }
    const topIds = Array.from(counts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15)
      .map(([id]) => id);
    if (topIds.length === 0) return [];

    const books = await this.prisma.book.findMany({ where: { id: { in: topIds } } });
    const byId = new Map(books.map((b) => [b.id, b]));
    return topIds
      .map((id) => {
        const book = byId.get(id);
        return book ? { book, count: counts.get(id)! } : null;
      })
      .filter((entry) => entry !== null);
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
        user: {
          select: {
            id: true,
            name: true,
            city: true,
            rating: true,
            profileImage: true,
          },
        },
      },
      take: 10,
    });
    return items.map((i) => this.toPublicPhotos(i));
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
      include: { user: { select: { id: true, name: true } } },
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
          ownerName: listing.user.name,
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
    return this.toPublicPhotos(userBook);
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

    const updated = await this.prisma.userBook.update({
      where: { id: userBookId },
      data: dto,
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

    return this.toPublicPhotos(updated);
  }

  async deleteUserBook(userId: string, userBookId: string) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

    await Promise.all(
      userBook.photos.map((path) => this.storage.deleteImage(path)),
    );

    await this.prisma.userBook.delete({ where: { id: userBookId } });
    return { message: 'Carte ștearsă din bibliotecă' };
  }

  async addPhoto(userId: string, userBookId: string, fileBuffer: Buffer) {
    const userBook = await this.getUserBook(userBookId);
    this.assertOwnership(userBook.userId, userId);

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

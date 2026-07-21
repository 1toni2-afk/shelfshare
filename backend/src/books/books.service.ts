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
import { BookLookupService } from './book-lookup.service';
import { AddBookDto } from './dto/add-book.dto';
import { UpdateUserBookDto } from './dto/update-user-book.dto';
import { SearchLibraryDto } from './dto/search-library.dto';
import { ROMANIAN_CITY_COORDINATES } from '../common/constants/romanian-city-coordinates';
import { RomanianCity } from '../common/constants/romanian-cities';
import { haversineDistanceKm } from '../common/utils/geo';
import { publicName } from '../common/utils/user-visibility';

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
  ) {}

  async searchExternal(query: string) {
    return this.lookup.searchByTitle(query);
  }

  async searchLibrary(filters: SearchLibraryDto) {
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

    const userBook = await this.prisma.userBook.create({
      data: {
        userId,
        bookId: book.id,
        condition: dto.condition,
        language: dto.language,
        edition: dto.edition,
        isHardcover: dto.isHardcover ?? false,
        isForSale: dto.isForSale ?? false,
        salePrice: dto.isForSale ? dto.salePrice : undefined,
        isNegotiable: dto.isForSale ? (dto.isNegotiable ?? true) : true,
      },
      include: { book: true },
    });

    this.wishlist.notifyWishlistedUsers(book.id, userId).catch(() => {});
    this.follow.notifyFollowersOfNewBook(userId, book.title).catch(() => {});

    return userBook;
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

  async getGenres() {
    const rows = await this.prisma.book.groupBy({
      by: ['genre'],
      where: {
        genre: { not: null },
        userBooks: { some: { availableForSwap: true } },
      },
      _count: { genre: true },
      orderBy: { _count: { genre: 'desc' } },
      take: 12,
    });
    return rows.map((r) => ({
      genre: r.genre as string,
      count: r._count.genre,
    }));
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
        isForSale: dto.isForSale ?? false,
        salePrice: dto.isForSale ? dto.salePrice : undefined,
        isNegotiable: dto.isForSale ? (dto.isNegotiable ?? true) : true,
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

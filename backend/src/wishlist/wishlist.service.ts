import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { WishlistItemSource } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ListingScoreService } from '../books/listing-score.service';

@Injectable()
export class WishlistService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private listingScore: ListingScoreService,
  ) {}

  async add(userId: string, bookId: string) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    // Nu-ți poți pune propria carte la favorite: dacă userul are deja un anunț
    // (UserBook) activ pentru acest titlu, e cartea LUI - inima nu are sens.
    // Soft-delete-urile nu blochează (deletedAt != null = scoasă din stoc), și
    // nici cărțile date deja la schimb (permanentlyTransferred: true) - altfel,
    // dacă cel care a primit-o o relistează, fostul proprietar nu mai poate
    // s-o pună pe wishlist pentru exemplarul NOU, fiindcă rândul lui vechi
    // (acum doar istoric) tot mai apărea ca "activ".
    const ownListing = await this.prisma.userBook.findFirst({
      where: { userId, bookId, deletedAt: null, permanentlyTransferred: false },
      select: { id: true },
    });
    if (ownListing) {
      throw new ConflictException(
        'Nu îți poți adăuga propria carte la favorite',
      );
    }

    const existing = await this.prisma.wishlistItem.findUnique({
      where: { userId_bookId: { userId, bookId } },
    });
    if (existing) {
      // Cartea a ajuns pe wishlist dintr-un „Yes" în Book Match (scânteie) -
      // un tap pe iconița din card confirmă alegerea ca favorit explicit
      // (inimă), nu aruncă eroare. Fără asta, tap-ul pe scânteie o elimina
      // de pe listă (toggle simplu), iar userul trebuia să mai dea click o
      // dată ca s-o și adauge înapoi ca favorit propriu-zis.
      if (existing.source === WishlistItemSource.BOOK_MATCH) {
        return this.prisma.wishlistItem.update({
          where: { id: existing.id },
          data: { source: WishlistItemSource.PERSONAL },
          include: { book: true },
        });
      }
      throw new ConflictException('Cartea este deja pe lista ta de dorințe');
    }

    const item = await this.prisma.wishlistItem.create({
      data: { userId, bookId },
      include: { book: true },
    });

    // Semnal de interes pentru „Cele mai căutate" - fire-and-forget, un
    // punct pierdut nu justifică să pice adăugarea la favorite.
    this.listingScore.recordWishlistAdd(bookId, userId).catch(() => {});

    return item;
  }

  async remove(userId: string, bookId: string) {
    await this.prisma.wishlistItem.deleteMany({ where: { userId, bookId } });
    return { message: 'Eliminat de pe lista de dorințe' };
  }

  getMine(userId: string) {
    return this.prisma.wishlistItem.findMany({
      where: { userId },
      include: { book: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Apelat când o carte devine disponibilă în biblioteca cuiva (adăugare
   * nouă sau redevine disponibilă după un schimb anulat). Notifică pe
   * toți cei care o au pe wishlist, exceptând persoana care tocmai a
   * adăugat-o (evident, nu se notifică singură).
   */
  async notifyWishlistedUsers(bookId: string, excludeUserId: string) {
    const wishlistedBy = await this.prisma.wishlistItem.findMany({
      where: { bookId, userId: { not: excludeUserId } },
      include: { book: true },
    });

    await Promise.all(
      wishlistedBy.map((item) =>
        this.notifications.create(
          item.userId,
          'WISHLIST_BOOK_AVAILABLE',
          `Cartea "${item.book.title}" de pe lista ta de dorințe este acum disponibilă!`,
          { bookId },
        ),
      ),
    );
  }

  /**
   * "Price Changed" - notifică userii care au cartea pe wishlist când
   * proprietarul îi modifică prețul de vânzare (nu se declanșează la prima
   * trecere pe vânzare - vezi apelantul din books.service.ts).
   */
  async notifyPriceChanged(bookId: string, excludeUserId: string, newPrice: number) {
    const wishlistedBy = await this.prisma.wishlistItem.findMany({
      where: { bookId, userId: { not: excludeUserId } },
      include: { book: true },
    });

    await Promise.all(
      wishlistedBy.map((item) =>
        this.notifications.create(
          item.userId,
          'PRICE_CHANGED',
          `Prețul cărții "${item.book.title}" de pe lista ta de dorințe s-a schimbat: ${newPrice} lei`,
          { bookId },
        ),
      ),
    );
  }
}

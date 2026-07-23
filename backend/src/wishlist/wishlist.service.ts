import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class WishlistService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  async add(userId: string, bookId: string) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    const existing = await this.prisma.wishlistItem.findUnique({
      where: { userId_bookId: { userId, bookId } },
    });
    if (existing) {
      throw new ConflictException('Cartea este deja pe lista ta de dorințe');
    }

    return this.prisma.wishlistItem.create({
      data: { userId, bookId },
      include: { book: true },
    });
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

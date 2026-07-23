import { Injectable, NotFoundException } from '@nestjs/common';
import { Book, BookshelfStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class BookshelfService {
  constructor(private prisma: PrismaService) {}

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

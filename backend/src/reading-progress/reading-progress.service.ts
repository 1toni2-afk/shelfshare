import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReadingProgressService {
  constructor(private prisma: PrismaService) {}

  async setProgress(userId: string, bookId: string, currentPage: number) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }
    // Peste numărul de pagini cunoscut, un "progres" nu mai are sens - clar
    // semn de input greșit (ex. userul a introdus anul, nu pagina).
    if (book.pageCount != null && currentPage > book.pageCount) {
      throw new BadRequestException(
        `Pagina nu poate depăși numărul total de pagini (${book.pageCount})`,
      );
    }

    return this.prisma.readingProgress.upsert({
      where: { userId_bookId: { userId, bookId } },
      create: { userId, bookId, currentPage },
      update: { currentPage },
      include: { book: true },
    });
  }

  getProgress(userId: string, bookId: string) {
    return this.prisma.readingProgress.findUnique({
      where: { userId_bookId: { userId, bookId } },
    });
  }

  getMyProgress(userId: string) {
    return this.prisma.readingProgress.findMany({
      where: { userId },
      include: { book: true },
      orderBy: { updatedAt: 'desc' },
    });
  }
}

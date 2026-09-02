import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReadingProgressService {
  constructor(private prisma: PrismaService) {}

  async setProgress(
    userId: string,
    bookId: string,
    currentPage: number,
    totalPages?: number,
  ) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    // Ediția userului bate catalogul: cine are în mână un tiraj cu alt număr
    // de pagini îl poate corecta, iar validarea de mai jos se face pe acel
    // total, nu pe `book.pageCount` (partajat între toți userii).
    const existing = await this.prisma.readingProgress.findUnique({
      where: { userId_bookId: { userId, bookId } },
    });
    const total = totalPages ?? existing?.totalPages ?? book.pageCount ?? null;

    // Peste numărul de pagini cunoscut, un "progres" nu mai are sens - clar
    // semn de input greșit (ex. userul a introdus anul, nu pagina).
    if (total != null && currentPage > total) {
      throw new BadRequestException(
        `Pagina nu poate depăși numărul total de pagini (${total})`,
      );
    }

    return this.prisma.readingProgress.upsert({
      where: { userId_bookId: { userId, bookId } },
      create: { userId, bookId, currentPage, totalPages: totalPages ?? null },
      update: {
        currentPage,
        ...(totalPages == null ? {} : { totalPages }),
      },
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

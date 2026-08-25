import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class BookOfMonthService {
  constructor(private prisma: PrismaService) {}

  /** "YYYY-MM" - cheia lunii curente, în UTC ca serverul să nu depindă de fusul propriu. */
  private currentMonth(): string {
    const now = new Date();
    return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
  }

  async vote(userId: string, bookId: string) {
    const book = await this.prisma.book.findUnique({ where: { id: bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    const month = this.currentMonth();
    return this.prisma.bookOfMonthVote.upsert({
      where: { userId_month: { userId, month } },
      create: { userId, bookId, month },
      update: { bookId },
      include: { book: true },
    });
  }

  async getMyVote(userId: string) {
    const month = this.currentMonth();
    return this.prisma.bookOfMonthVote.findUnique({
      where: { userId_month: { userId, month } },
      include: { book: true },
    });
  }

  /**
   * Câștigătorul curent, calculat direct din voturi (groupBy), nu dintr-un
   * rând salvat separat - vezi comentariul de pe model în schema.prisma.
   */
  async getCurrentWinner() {
    const month = this.currentMonth();
    const [top] = await this.prisma.bookOfMonthVote.groupBy({
      by: ['bookId'],
      where: { month },
      _count: { bookId: true },
      orderBy: { _count: { bookId: 'desc' } },
      take: 1,
    });

    if (!top) {
      return { book: null, voteCount: 0, totalVotes: 0 };
    }

    const [book, totalVotes] = await Promise.all([
      this.prisma.book.findUnique({ where: { id: top.bookId } }),
      this.prisma.bookOfMonthVote.count({ where: { month } }),
    ]);

    return { book, voteCount: top._count.bookId, totalVotes };
  }
}

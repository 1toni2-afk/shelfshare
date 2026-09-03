import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { publicName } from '../common/utils/user-visibility';
import { UpsertReviewDto } from './dto/upsert-review.dto';
import { ReportReviewDto } from './dto/report-review.dto';
import { ReportsService } from '../reports/reports.service';

const AUTHOR_SELECT = { name: true, nameVisible: true, profileImage: true };

@Injectable()
export class ReviewsService {
  constructor(
    private prisma: PrismaService,
    private reports: ReportsService,
  ) {}

  async upsert(userId: string, dto: UpsertReviewDto) {
    const book = await this.prisma.book.findUnique({ where: { id: dto.bookId } });
    if (!book) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }

    const review = await this.prisma.review.upsert({
      where: { userId_bookId: { userId, bookId: dto.bookId } },
      create: { userId, bookId: dto.bookId, rating: dto.rating, text: dto.text },
      update: { rating: dto.rating, text: dto.text },
      include: { user: { select: AUTHOR_SELECT } },
    });

    return this.sanitizeAuthor(review);
  }

  async getForBook(bookId: string) {
    const [reviews, aggregate] = await Promise.all([
      this.prisma.review.findMany({
        // Recenziile ascunse automat (vezi ReportsService.applyAutoHide) ies
        // din pagina cărții, dar rămân în baza de date pentru moderator.
        where: { bookId, hiddenAt: null },
        include: { user: { select: AUTHOR_SELECT } },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.review.aggregate({
        where: { bookId, hiddenAt: null },
        _avg: { rating: true },
        _count: { rating: true },
      }),
    ]);

    return {
      averageRating: aggregate._avg.rating,
      reviewCount: aggregate._count.rating,
      reviews: reviews.map((r) => this.sanitizeAuthor(r)),
    };
  }

  /**
   * Recenziile unei OPERE, adunate peste toate edițiile ei (vezi
   * BooksService.getWork - `Book` e per ediție, iar o recenzie scrisă pe
   * ediția din 2001 e despre aceeași carte ca una scrisă pe cea din 2019).
   * `getForBook` rămâne pentru pagina unei singure ediții.
   */
  async getForBooks(bookIds: string[]) {
    if (bookIds.length === 0) {
      return { averageRating: null, reviewCount: 0, reviews: [] };
    }
    const [reviews, aggregate] = await Promise.all([
      this.prisma.review.findMany({
        where: { bookId: { in: bookIds }, hiddenAt: null },
        include: { user: { select: AUTHOR_SELECT } },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      this.prisma.review.aggregate({
        where: { bookId: { in: bookIds }, hiddenAt: null },
        _avg: { rating: true },
        _count: { rating: true },
      }),
    ]);

    return {
      averageRating: aggregate._avg.rating,
      reviewCount: aggregate._count.rating,
      reviews: reviews.map((r) => this.sanitizeAuthor(r)),
    };
  }

  getMine(userId: string, bookId: string) {
    return this.prisma.review.findUnique({
      where: { userId_bookId: { userId, bookId } },
    });
  }

  async remove(userId: string, bookId: string) {
    const review = await this.prisma.review.findUnique({
      where: { userId_bookId: { userId, bookId } },
    });
    if (!review) {
      throw new NotFoundException('Recenzia nu a fost găsită');
    }
    if (review.userId !== userId) {
      throw new ForbiddenException('Poți șterge doar propria recenzie');
    }
    await this.prisma.review.delete({ where: { id: review.id } });
    return { message: 'Recenzie ștearsă' };
  }

  async reportReview(reviewId: string, reporterId: string, dto: ReportReviewDto) {
    const review = await this.prisma.review.findUnique({ where: { id: reviewId } });
    if (!review) {
      throw new NotFoundException('Recenzia nu a fost găsită');
    }
    if (review.userId === reporterId) {
      throw new BadRequestException('Nu îți poți raporta propria recenzie');
    }
    return this.reports.create({
      reporterId,
      reportedUserId: review.userId,
      targetType: 'REVIEW',
      targetId: reviewId,
      reason: dto.reason,
      details: dto.details,
      extra: { reviewId },
    });
  }

  private sanitizeAuthor<T extends { user: { name: string | null; nameVisible: boolean } }>(
    review: T,
  ): T {
    return { ...review, user: { ...review.user, name: publicName(review.user) } };
  }
}

import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ReportReason } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ReportsService } from '../reports/reports.service';
import { publicName } from '../common/utils/user-visibility';

const EVENT_TYPES = [
  'new_listing',
  'finished_book',
  'completed_exchange',
  'sale',
  'reading_progress',
] as const;
type EventType = (typeof EVENT_TYPES)[number];

export const MAX_COMMENT_LENGTH = 1000;

/** Câmpurile de care are nevoie `decorate` din fiecare eveniment de feed. */
interface FeedEventCore {
  id: string;
  type: EventType;
  userId: string;
  bookId: string;
}

/**
 * Partea socială a feedului: aprecieri, comentarii și starea „ce am făcut eu
 * deja cu cartea asta" (dorită, în curs de citire).
 *
 * Evenimentele nu au tabelă proprie - ProfileService.getActivityFeed le
 * recompune la citire. Ținta aprecierilor și comentariilor e deci o cheie
 * `tip:idSursă`, iar `resolveEvent` verifică de fiecare dată că rândul sursă
 * există încă: altfel s-ar putea aprecia sau comenta un eveniment inventat.
 */
@Injectable()
export class FeedSocialService {
  constructor(
    private prisma: PrismaService,
    private reports: ReportsService,
  ) {}

  /**
   * Adaugă pe fiecare eveniment contoarele și starea privitorului. Câte o
   * interogare pe tip de informație pentru toată pagina, nu per eveniment.
   */
  async decorate<T extends FeedEventCore>(viewerId: string, events: T[]) {
    if (events.length === 0) return [];
    const keys = events.map((e) => e.id);
    const bookIds = [...new Set(events.map((e) => e.bookId))];
    const finished = events.filter((e) => e.type === 'finished_book');

    const [likeCounts, myLikes, commentCounts, wishlist, reading, reviews] = await Promise.all([
      this.prisma.feedLike.groupBy({
        by: ['eventKey'],
        where: { eventKey: { in: keys } },
        _count: { _all: true },
      }),
      this.prisma.feedLike.findMany({
        where: { userId: viewerId, eventKey: { in: keys } },
        select: { eventKey: true },
      }),
      this.prisma.feedComment.groupBy({
        by: ['eventKey'],
        where: { eventKey: { in: keys }, hiddenAt: null },
        _count: { _all: true },
      }),
      this.prisma.wishlistItem.findMany({
        where: { userId: viewerId, bookId: { in: bookIds } },
        select: { bookId: true },
      }),
      this.prisma.bookshelfEntry.findMany({
        where: { userId: viewerId, bookId: { in: bookIds }, status: 'READING' },
        select: { bookId: true },
      }),
      // Nota și părerea celui care a terminat cartea - stelele și citatul de
      // pe cardul „A terminat". Recenziile ascunse de moderare nu apar.
      finished.length === 0
        ? []
        : this.prisma.review.findMany({
            where: {
              hiddenAt: null,
              OR: finished.map((e) => ({ userId: e.userId, bookId: e.bookId })),
            },
            select: { userId: true, bookId: true, rating: true, text: true },
            orderBy: { updatedAt: 'desc' },
          }),
    ]);

    const likes = new Map(likeCounts.map((row) => [row.eventKey, row._count._all]));
    const liked = new Set(myLikes.map((row) => row.eventKey));
    const comments = new Map(commentCounts.map((row) => [row.eventKey, row._count._all]));
    const wished = new Set(wishlist.map((row) => row.bookId));
    const readingNow = new Set(reading.map((row) => row.bookId));
    const reviewByPair = new Map<string, { rating: number; text: string | null }>();
    for (const review of reviews) {
      const pair = `${review.userId}:${review.bookId}`;
      if (!reviewByPair.has(pair)) reviewByPair.set(pair, review);
    }

    return events.map((event) => {
      const review =
        event.type === 'finished_book'
          ? reviewByPair.get(`${event.userId}:${event.bookId}`)
          : undefined;
      return {
        ...event,
        likeCount: likes.get(event.id) ?? 0,
        likedByMe: liked.has(event.id),
        commentCount: comments.get(event.id) ?? 0,
        wishlistedByMe: wished.has(event.bookId),
        readingByMe: readingNow.has(event.bookId),
        rating: review?.rating ?? null,
        reviewText: review?.text?.trim() || null,
      };
    });
  }

  async like(userId: string, eventKey: string) {
    await this.resolveEvent(eventKey);
    // upsert: al doilea „like" din alt tab nu e o eroare, starea e aceeași.
    await this.prisma.feedLike.upsert({
      where: { userId_eventKey: { userId, eventKey } },
      create: { userId, eventKey },
      update: {},
    });
    return this.likeState(userId, eventKey);
  }

  async unlike(userId: string, eventKey: string) {
    await this.prisma.feedLike.deleteMany({ where: { userId, eventKey } });
    return this.likeState(userId, eventKey);
  }

  private async likeState(userId: string, eventKey: string) {
    const [likeCount, mine] = await Promise.all([
      this.prisma.feedLike.count({ where: { eventKey } }),
      this.prisma.feedLike.count({ where: { eventKey, userId } }),
    ]);
    return { likeCount, likedByMe: mine > 0 };
  }

  async comments(viewerId: string, eventKey: string) {
    const { actorIds } = await this.resolveEvent(eventKey);
    const rows = await this.prisma.feedComment.findMany({
      where: { eventKey, hiddenAt: null },
      include: { user: { select: { id: true, name: true, nameVisible: true, profileImage: true } } },
      orderBy: { createdAt: 'asc' },
      take: 200,
    });
    return rows.map((row) => this.toDto(row, viewerId, actorIds));
  }

  async addComment(userId: string, eventKey: string, rawText: string) {
    const text = (rawText ?? '').trim();
    if (!text) throw new BadRequestException('Comentariul e gol');
    if (text.length > MAX_COMMENT_LENGTH) {
      throw new BadRequestException(`Comentariul poate avea cel mult ${MAX_COMMENT_LENGTH} de caractere`);
    }
    const { actorIds } = await this.resolveEvent(eventKey);
    const row = await this.prisma.feedComment.create({
      data: { userId, eventKey, text },
      include: { user: { select: { id: true, name: true, nameVisible: true, profileImage: true } } },
    });
    return this.toDto(row, userId, actorIds);
  }

  /**
   * Șterge autorul comentariului sau cel despre care e evenimentul - e „sub
   * postarea lui", deci trebuie să poată scoate ce nu vrea acolo.
   */
  async deleteComment(userId: string, commentId: string) {
    const comment = await this.prisma.feedComment.findUnique({ where: { id: commentId } });
    if (!comment) throw new NotFoundException('Comentariul nu a fost găsit');
    if (comment.userId !== userId) {
      const { actorIds } = await this.resolveEvent(comment.eventKey).catch(() => ({
        actorIds: [] as string[],
      }));
      if (!actorIds.includes(userId)) {
        throw new ForbiddenException('Nu poți șterge acest comentariu');
      }
    }
    await this.prisma.feedComment.delete({ where: { id: commentId } });
    return { deleted: true };
  }

  async reportComment(
    reporterId: string,
    commentId: string,
    reason: ReportReason,
    details?: string,
  ) {
    const comment = await this.prisma.feedComment.findUnique({ where: { id: commentId } });
    if (!comment || comment.hiddenAt) {
      throw new NotFoundException('Comentariul nu a fost găsit');
    }
    return this.reports.create({
      reporterId,
      reportedUserId: comment.userId,
      targetType: 'FEED_COMMENT',
      targetId: commentId,
      reason,
      details,
      extra: { feedCommentId: commentId },
    });
  }

  private toDto(
    row: {
      id: string;
      text: string;
      createdAt: Date;
      user: { id: string; name: string | null; nameVisible: boolean; profileImage: string | null };
    },
    viewerId: string,
    actorIds: string[],
  ) {
    return {
      id: row.id,
      text: row.text,
      createdAt: row.createdAt,
      user: {
        id: row.user.id,
        name: publicName(row.user),
        profileImage: row.user.profileImage,
      },
      isMine: row.user.id === viewerId,
      canDelete: row.user.id === viewerId || actorIds.includes(viewerId),
    };
  }

  /**
   * Verifică existența evenimentului din spatele cheii și întoarce cine e
   * „proprietarul" lui (la un schimb, ambii participanți).
   */
  private async resolveEvent(eventKey: string): Promise<{ actorIds: string[] }> {
    const separator = eventKey.indexOf(':');
    const type = eventKey.slice(0, separator) as EventType;
    const id = eventKey.slice(separator + 1);
    if (separator <= 0 || !id || !EVENT_TYPES.includes(type)) {
      throw new BadRequestException('Eveniment invalid');
    }

    let actorIds: string[] | null = null;
    switch (type) {
      case 'new_listing': {
        const row = await this.prisma.userBook.findFirst({
          where: { id, deletedAt: null, hiddenAt: null },
          select: { userId: true },
        });
        actorIds = row ? [row.userId] : null;
        break;
      }
      case 'finished_book': {
        const row = await this.prisma.bookshelfEntry.findFirst({
          where: { id, status: 'FINISHED' },
          select: { userId: true },
        });
        actorIds = row ? [row.userId] : null;
        break;
      }
      case 'completed_exchange': {
        const row = await this.prisma.exchangeRequest.findFirst({
          where: { id, status: 'COMPLETED' },
          select: { requesterId: true, ownerId: true },
        });
        actorIds = row ? [row.requesterId, row.ownerId] : null;
        break;
      }
      case 'sale': {
        const row = await this.prisma.priceOffer.findFirst({
          where: { id, status: 'COMPLETED' },
          select: { ownerId: true },
        });
        actorIds = row ? [row.ownerId] : null;
        break;
      }
      case 'reading_progress': {
        const row = await this.prisma.readingProgress.findUnique({
          where: { id },
          select: { userId: true },
        });
        actorIds = row ? [row.userId] : null;
        break;
      }
    }
    if (!actorIds) throw new NotFoundException('Evenimentul nu mai există');
    return { actorIds };
  }
}

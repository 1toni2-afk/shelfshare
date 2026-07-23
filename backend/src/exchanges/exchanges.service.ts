import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotificationType } from '@prisma/client';
import { CreateExchangeRequestDto } from './dto/create-exchange-request.dto';
import { RateExchangeDto } from './dto/rate-exchange.dto';
import { SetMeetingDto } from './dto/set-meeting.dto';
import { publicName } from '../common/utils/user-visibility';
import { awardXp, XP_EXCHANGE_COMPLETED, XP_REVIEW_WRITTEN } from '../common/utils/xp';

// Offer Expiration (Milestone 3) - o cerere PENDING neatinsă expiră automat
// după atâtea zile, ca să nu rămână la nesfârșit "în așteptare" fără răspuns.
const OFFER_EXPIRY_DAYS = 7;

const INCLUDE_FULL = {
  requestedBook: { include: { book: true } },
  offeredBook: { include: { book: true } },
  requester: {
    select: {
      id: true,
      name: true,
      username: true,
      nameVisible: true,
      city: true,
      rating: true,
      profileImage: true,
    },
  },
  owner: {
    select: {
      id: true,
      name: true,
      username: true,
      nameVisible: true,
      city: true,
      rating: true,
      profileImage: true,
    },
  },
} as const;

@Injectable()
export class ExchangesService {
  private readonly logger = new Logger(ExchangesService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  /**
   * Notificarea e un efect secundar, nu partea esențială a acțiunii -
   * schimbul deja s-a salvat în DB când ajungem aici. Dacă notificarea
   * eșuează, nu vrem ca clientul să vadă un 500 pentru o acțiune care
   * de fapt a reușit (și posibil s-o reîncerce, creând un duplicat).
   */
  private async notifySafe(
    userId: string,
    type: NotificationType,
    message: string,
    data: Record<string, unknown>,
  ) {
    try {
      await this.notifications.create(userId, type, message, data);
    } catch (error) {
      this.logger.warn(
        `Nu am putut trimite notificarea "${type}" către ${userId}: ${error}`,
      );
    }
  }

  private sanitizeParties<
    T extends {
      requester: { name: string | null; nameVisible: boolean };
      owner: { name: string | null; nameVisible: boolean };
    },
  >(request: T): T {
    return {
      ...request,
      requester: { ...request.requester, name: publicName(request.requester) },
      owner: { ...request.owner, name: publicName(request.owner) },
    };
  }

  async createRequest(requesterId: string, dto: CreateExchangeRequestDto) {
    const requestedBook = await this.prisma.userBook.findUnique({
      where: { id: dto.requestedBookId },
      include: { book: true },
    });
    if (!requestedBook) {
      throw new NotFoundException('Cartea cerută nu a fost găsită');
    }
    if (requestedBook.userId === requesterId) {
      throw new BadRequestException('Nu poți cere propria carte la schimb');
    }
    if (!requestedBook.availableForSwap) {
      throw new BadRequestException(
        'Această carte nu mai este disponibilă la schimb',
      );
    }

    if (dto.offeredBookId) {
      const offeredBook = await this.prisma.userBook.findUnique({
        where: { id: dto.offeredBookId },
      });
      if (!offeredBook) {
        throw new NotFoundException('Cartea oferită nu a fost găsită');
      }
      if (offeredBook.userId !== requesterId) {
        throw new BadRequestException(
          'Poți oferi la schimb doar cărți din biblioteca ta',
        );
      }
      if (!offeredBook.availableForSwap) {
        throw new BadRequestException(
          'Cartea pe care vrei s-o oferi nu este disponibilă',
        );
      }
    }

    const created = await this.prisma.exchangeRequest.create({
      data: {
        requesterId,
        ownerId: requestedBook.userId,
        requestedBookId: dto.requestedBookId,
        offeredBookId: dto.offeredBookId,
        offeredAmount: dto.offeredAmount,
        message: dto.message,
        expiresAt: new Date(Date.now() + OFFER_EXPIRY_DAYS * 86_400_000),
      },
      include: INCLUDE_FULL,
    });

    await this.notifySafe(
      requestedBook.userId,
      'EXCHANGE_REQUEST_RECEIVED',
      `Ai primit o cerere de schimb pentru "${requestedBook.book.title}"`,
      { exchangeRequestId: created.id },
    );

    return this.sanitizeParties(created);
  }

  async getSentRequests(userId: string) {
    await this.expireStalePending({ requesterId: userId });
    const requests = await this.prisma.exchangeRequest.findMany({
      where: { requesterId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
    return requests.map((r) => this.sanitizeParties(r));
  }

  async getReceivedRequests(userId: string) {
    await this.expireStalePending({ ownerId: userId });
    const requests = await this.prisma.exchangeRequest.findMany({
      where: { ownerId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
    return requests.map((r) => this.sanitizeParties(r));
  }

  private async expireStalePending(where: { requesterId?: string; ownerId?: string }) {
    await this.prisma.exchangeRequest.updateMany({
      where: { ...where, status: 'PENDING', expiresAt: { lt: new Date() } },
      data: { status: 'EXPIRED' },
    });
  }

  async getRequest(id: string, userId: string) {
    const request = await this.findOwnedRequest(id, userId);
    return request;
  }

  /**
   * Owner-ul acceptă cererea. Ambele cărți implicate devin indisponibile,
   * cât timp schimbul e în desfășurare (nu mai apar în alte căutări).
   */
  async accept(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    this.assertIsOwner(request, userId);
    this.assertStatus(request, 'PENDING');

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.userBook.update({
        where: { id: request.requestedBookId },
        data: { availableForSwap: false },
      });
      if (request.offeredBookId) {
        await tx.userBook.update({
          where: { id: request.offeredBookId },
          data: { availableForSwap: false },
        });
      }

      return tx.exchangeRequest.update({
        where: { id },
        data: { status: 'ACCEPTED' },
        include: INCLUDE_FULL,
      });
    });

    await this.notifySafe(
      request.requesterId,
      'EXCHANGE_REQUEST_ACCEPTED',
      `Cererea ta de schimb pentru "${updated.requestedBook.book.title}" a fost acceptată`,
      { exchangeRequestId: id },
    );

    return this.sanitizeParties(updated);
  }

  async reject(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    this.assertIsOwner(request, userId);
    this.assertStatus(request, 'PENDING');

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: { status: 'REJECTED' },
      include: INCLUDE_FULL,
    });

    await this.notifySafe(
      request.requesterId,
      'EXCHANGE_REQUEST_REJECTED',
      `Cererea ta de schimb pentru "${updated.requestedBook.book.title}" a fost refuzată`,
      { exchangeRequestId: id },
    );

    return this.sanitizeParties(updated);
  }

  async cancel(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    this.assertIsRequester(request, userId);
    this.assertStatus(request, 'PENDING');

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: { status: 'CANCELLED' },
      include: INCLUDE_FULL,
    });
    return this.sanitizeParties(updated);
  }

  /**
   * Oricare dintre cei doi participanți poate marca schimbul ca finalizat.
   * Incrementăm contorul de cărți schimbate pentru amândoi - folosit
   * pentru rating și statistici pe profil.
   */
  async complete(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    if (request.requesterId !== userId && request.ownerId !== userId) {
      throw new ForbiddenException('Nu ești parte în acest schimb');
    }
    this.assertStatus(request, 'ACCEPTED');

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: request.requesterId },
        data: {
          booksExchangedCount: { increment: 1 },
          booksReceivedCount: { increment: 1 },
          xp: { increment: XP_EXCHANGE_COMPLETED },
        },
      });
      await tx.user.update({
        where: { id: request.ownerId },
        data: {
          booksExchangedCount: { increment: 1 },
          booksSharedCount: { increment: 1 },
          xp: { increment: XP_EXCHANGE_COMPLETED },
        },
      });

      return tx.exchangeRequest.update({
        where: { id },
        data: { status: 'COMPLETED' },
        include: INCLUDE_FULL,
      });
    });
    return this.sanitizeParties(updated);
  }

  /**
   * Oricare dintre cei doi participanți poate evalua cealaltă parte,
   * o singură dată, după ce schimbul e COMPLETED. Rating-ul de profil
   * e media tuturor evaluărilor primite din toate schimburile.
   */
  async rate(id: string, userId: string, dto: RateExchangeDto) {
    const request = await this.findRequestForAction(id);
    if (request.requesterId !== userId && request.ownerId !== userId) {
      throw new ForbiddenException('Nu ești parte în acest schimb');
    }
    this.assertStatus(request, 'COMPLETED');

    const isRequester = request.requesterId === userId;
    const ratedUserId = isRequester ? request.ownerId : request.requesterId;

    if (isRequester && request.requesterRatingForOwner !== null) {
      throw new BadRequestException('Ai evaluat deja acest schimb');
    }
    if (!isRequester && request.ownerRatingForRequester !== null) {
      throw new BadRequestException('Ai evaluat deja acest schimb');
    }

    await this.prisma.exchangeRequest.update({
      where: { id },
      data: isRequester
        ? {
            requesterRatingForOwner: dto.value,
            requesterReviewForOwner: dto.comment,
            requesterCommunicationForOwner: dto.communication,
            requesterPunctualityForOwner: dto.punctuality,
            requesterConditionForOwner: dto.condition,
          }
        : {
            ownerRatingForRequester: dto.value,
            ownerReviewForRequester: dto.comment,
            ownerCommunicationForRequester: dto.communication,
            ownerPunctualityForRequester: dto.punctuality,
            ownerConditionForRequester: dto.condition,
          },
    });

    await this.recomputeRating(ratedUserId);
    await awardXp(this.prisma, userId, XP_REVIEW_WRITTEN);

    return this.findOwnedRequest(id, userId);
  }

  /**
   * Oricare dintre cei doi participanți poate programa/reprograma
   * întâlnirea, cât timp schimbul e ACCEPTED.
   */
  async setMeeting(id: string, userId: string, dto: SetMeetingDto) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: {
        meetingTime: new Date(dto.meetingTime),
        meetingLocation: dto.meetingLocation,
      },
      include: INCLUDE_FULL,
    });

    const otherUserId =
      userId === updated.requesterId ? updated.ownerId : updated.requesterId;
    await this.notifySafe(
      otherUserId,
      'EXCHANGE_MEETING_SCHEDULED',
      `Întâlnirea pentru "${updated.requestedBook.book.title}" a fost programată`,
      { exchangeRequestId: updated.id },
    );

    return this.sanitizeParties(updated);
  }

  /** Generează un fișier .ics pentru întâlnirea de schimb, ca oricare parte să-l poată importa în calendar. */
  async generateIcs(id: string, userId: string): Promise<string> {
    const request = await this.findOwnedRequest(id, userId);
    if (!request.meetingTime) {
      throw new BadRequestException(
        'Nu a fost programată încă o întâlnire pentru acest schimb',
      );
    }

    const start = request.meetingTime;
    const end = new Date(start.getTime() + 60 * 60 * 1000);

    const escape = (text: string) =>
      text
        .replace(/\\/g, '\\\\')
        .replace(/,/g, '\\,')
        .replace(/;/g, '\\;')
        .replace(/\n/g, '\\n');

    const formatDate = (date: Date) =>
      date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';

    const requesterName = request.requester.name ?? 'Cineva';
    const ownerName = request.owner.name ?? 'Cineva';
    const bookTitle = request.requestedBook.book.title;
    const verb = request.offeredAmount != null ? 'cumpăra' : 'schimba';
    const priceClause =
      request.offeredAmount != null ? ` (la prețul de ${request.offeredAmount} lei)` : '';

    const summary = 'Schimb de carte';
    const description = `${requesterName} se întâlnește cu ${ownerName} pentru a ${verb} cartea „${bookTitle}"${priceClause}`;

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ShelfShare//Exchange//RO',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      `UID:${request.id}@shelfshare`,
      `DTSTAMP:${formatDate(new Date())}`,
      `DTSTART:${formatDate(start)}`,
      `DTEND:${formatDate(end)}`,
      `SUMMARY:${escape(summary)}`,
      `LOCATION:${escape(request.meetingLocation ?? '')}`,
      `DESCRIPTION:${escape(description)}`,
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  private async recomputeRating(userId: string) {
    const ratedExchanges = await this.prisma.exchangeRequest.findMany({
      where: {
        OR: [
          { ownerId: userId, requesterRatingForOwner: { not: null } },
          { requesterId: userId, ownerRatingForRequester: { not: null } },
        ],
      },
      select: {
        requesterRatingForOwner: true,
        ownerRatingForRequester: true,
        requesterCommunicationForOwner: true,
        requesterPunctualityForOwner: true,
        requesterConditionForOwner: true,
        ownerCommunicationForRequester: true,
        ownerPunctualityForRequester: true,
        ownerConditionForRequester: true,
      },
    });

    const values = ratedExchanges
      .map((r) => r.requesterRatingForOwner ?? r.ownerRatingForRequester)
      .filter((v): v is number => v !== null);

    const communicationValues = ratedExchanges
      .map((r) => r.requesterCommunicationForOwner ?? r.ownerCommunicationForRequester)
      .filter((v): v is number => v !== null);
    const punctualityValues = ratedExchanges
      .map((r) => r.requesterPunctualityForOwner ?? r.ownerPunctualityForRequester)
      .filter((v): v is number => v !== null);
    const conditionValues = ratedExchanges
      .map((r) => r.requesterConditionForOwner ?? r.ownerConditionForRequester)
      .filter((v): v is number => v !== null);

    const average = (nums: number[]) =>
      nums.length === 0 ? 0 : Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 10) / 10;

    const rating = average(values);

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        rating,
        avgCommunicationRating: average(communicationValues),
        avgPunctualityRating: average(punctualityValues),
        avgConditionRating: average(conditionValues),
      },
    });
  }

  // ---------- Helpers ----------

  private async findRequestForAction(id: string) {
    const request = await this.prisma.exchangeRequest.findUnique({
      where: { id },
    });
    if (!request) {
      throw new NotFoundException('Cererea de schimb nu a fost găsită');
    }
    return this.expireIfStale(request);
  }

  /**
   * Expirare "leneșă" - vezi comentariul de pe ExchangeRequest.expiresAt în
   * schema.prisma. Verificată la fiecare citire, nu printr-un job separat.
   */
  private async expireIfStale<T extends { id: string; status: string; expiresAt: Date | null }>(
    request: T,
  ): Promise<T> {
    if (request.status !== 'PENDING' || !request.expiresAt || request.expiresAt > new Date()) {
      return request;
    }
    await this.prisma.exchangeRequest.update({
      where: { id: request.id },
      data: { status: 'EXPIRED' },
    });
    return { ...request, status: 'EXPIRED' };
  }

  private async findOwnedRequest(id: string, userId: string) {
    const request = await this.prisma.exchangeRequest.findUnique({
      where: { id },
      include: INCLUDE_FULL,
    });
    if (!request) {
      throw new NotFoundException('Cererea de schimb nu a fost găsită');
    }
    if (request.requesterId !== userId && request.ownerId !== userId) {
      throw new ForbiddenException('Nu ești parte în acest schimb');
    }
    return this.sanitizeParties(await this.expireIfStale(request));
  }

  private assertIsOwner(request: { ownerId: string }, userId: string) {
    if (request.ownerId !== userId) {
      throw new ForbiddenException('Doar proprietarul cărții poate face asta');
    }
  }

  private assertIsRequester(request: { requesterId: string }, userId: string) {
    if (request.requesterId !== userId) {
      throw new ForbiddenException('Doar solicitantul poate face asta');
    }
  }

  private assertStatus(request: { status: string }, expected: string) {
    if (request.status !== expected) {
      throw new BadRequestException(
        `Acțiunea nu este permisă - cererea are statusul "${request.status}"`,
      );
    }
  }
}

import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ConversationsService } from '../chat/conversations.service';
import { ListingScoreService } from '../books/listing-score.service';
import { ActivityLogService } from '../activity-log/activity-log.service';
import { NotificationType } from '@prisma/client';
import { CreateOfferDto } from './dto/create-offer.dto';
import { CounterOfferDto } from './dto/counter-offer.dto';
import { SetMeetingDto } from '../exchanges/dto/set-meeting.dto';
import { CancelExchangeDto } from '../exchanges/dto/cancel-exchange.dto';
import { ShareContactDto } from '../exchanges/dto/share-contact.dto';
import { publicName } from '../common/utils/user-visibility';
import { XP_SALE_COMPLETED } from '../common/utils/xp';

// Offer Expiration (Milestone 3) - vezi comentariul din exchanges.service.ts.
const OFFER_EXPIRY_DAYS = 7;

// Timeout-ul vânzării "în desfășurare" - vezi comentariul analog din
// exchanges.service.ts#EXCHANGE_TIMEOUT_DAYS.
const SALE_TIMEOUT_DAYS = 7;

const CANCEL_REASON_MESSAGES: Record<string, string> = {
  no_show: 'cealaltă persoană nu s-a prezentat',
  book_mismatch: 'cartea nu a corespuns așteptărilor',
  changed_mind: 's-a răzgândit',
  other: 'motiv nespecificat',
  expired: 'termenul de 7 zile a expirat fără nicio confirmare',
};

const INCLUDE_FULL = {
  userBook: { include: { book: true } },
  buyer: {
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
export class OffersService {
  private readonly logger = new Logger(OffersService.name);

  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
    private conversations: ConversationsService,
    private listingScore: ListingScoreService,
    private activityLog: ActivityLogService,
  ) {}

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
      buyer: { name: string | null; nameVisible: boolean };
      owner: { name: string | null; nameVisible: boolean };
    },
  >(offer: T): T {
    return {
      ...offer,
      buyer: { ...offer.buyer, name: publicName(offer.buyer) },
      owner: { ...offer.owner, name: publicName(offer.owner) },
    };
  }

  async createOffer(buyerId: string, userBookId: string, dto: CreateOfferDto) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      include: { book: true },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }
    if (userBook.userId === buyerId) {
      throw new BadRequestException(
        'Nu poți face o ofertă pentru propria carte',
      );
    }
    // Un anunț de tip Schimb cu „sau vinde cu X lei" acceptă oferte în bani
    // la fel ca unul de vânzare, deși isForSale rămâne false (vezi
    // UserBook.swapSalePrice).
    const acceptsMoneyOffers =
      userBook.isForSale || userBook.swapSalePrice != null;
    if (!acceptsMoneyOffers) {
      throw new BadRequestException('Această carte nu este de vânzare');
    }
    if (userBook.isForSale && !userBook.isNegotiable) {
      throw new BadRequestException('Prețul acestei cărți nu este negociabil');
    }

    const created = await this.prisma.priceOffer.create({
      data: {
        buyerId,
        ownerId: userBook.userId,
        userBookId,
        amount: dto.amount,
        message: dto.message,
        expiresAt: new Date(Date.now() + OFFER_EXPIRY_DAYS * 86_400_000),
      },
      include: INCLUDE_FULL,
    });

    const buyer = await this.prisma.user.findUnique({ where: { id: buyerId } });

    // Oferta devine vizibilă și acționabilă direct în chat, nu doar o
    // notificare separată - vezi Message.priceOfferId.
    const conversation = await this.conversations.findOrCreateConversation(
      buyerId,
      userBook.userId,
    );
    await this.conversations.createPriceOfferMessage(
      conversation.id,
      buyerId,
      created.id,
      `Ofertă: ${dto.amount} lei pentru "${userBook.book.title}"`,
    );

    await this.notifySafe(
      userBook.userId,
      'PRICE_OFFER_RECEIVED',
      `${buyer?.name ?? 'Un utilizator'} ți-a oferit ${dto.amount} lei pentru cartea ta "${userBook.book.title}"`,
      { offerId: created.id, conversationId: conversation.id },
    );

    // Cel mai puternic semnal de interes pentru „Cele mai căutate" -
    // fire-and-forget, un punct pierdut nu justifică să pice oferta.
    this.listingScore.recordBuyOffer(userBookId, buyerId).catch(() => {});

    this.activityLog.record({
      action: 'OFFER_CREATED',
      actorId: buyerId,
      targetId: userBook.userId,
      details: {
        offerId: created.id,
        carte: userBook.book.title,
        suma: dto.amount,
      },
    });

    // Frontend-ul deschide chatul cu cumpărătorul direct după trimiterea
    // ofertei - vezi book_detail_screen.dart#_MakeOfferSheet.
    return { ...this.sanitizeParties(created), conversationId: conversation.id };
  }

  async getSentOffers(userId: string) {
    await this.expireStalePending({ buyerId: userId });
    const offers = await this.prisma.priceOffer.findMany({
      where: { buyerId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
    return offers.map((o) => this.sanitizeParties(o));
  }

  async getReceivedOffers(userId: string) {
    await this.expireStalePending({ ownerId: userId });
    const offers = await this.prisma.priceOffer.findMany({
      where: { ownerId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
    return offers.map((o) => this.sanitizeParties(o));
  }

  async getOne(id: string, userId: string) {
    return this.findOwnedOffer(id, userId);
  }

  private async expireStalePending(where: {
    buyerId?: string;
    ownerId?: string;
  }) {
    await this.prisma.priceOffer.updateMany({
      where: { ...where, status: 'PENDING', expiresAt: { lt: new Date() } },
      data: { status: 'EXPIRED' },
    });
  }

  /**
   * Owner-ul acceptă oferta - cartea devine indisponibilă cât timp vânzarea e
   * "în desfășurare", dar NU se transferă încă: trebuie parcurs întâi
   * întregul flow (programare/contact/safety/Done mutual), la fel ca la un
   * schimb carte-contra-carte. Vezi markDone() pentru transferul efectiv.
   */
  async accept(id: string, userId: string) {
    const offer = await this.findForAction(id);
    this.assertIsOwner(offer, userId);
    this.assertStatus(offer, 'PENDING');

    const updated = await this.prisma.$transaction(async (tx) => {
      // Atomic guards prevent two concurrent accept() calls (e.g. on two
      // different pending offers for the same book) from both succeeding.
      const offerClaim = await tx.priceOffer.updateMany({
        where: { id, status: 'PENDING' },
        data: { status: 'ACCEPTED', acceptedAt: new Date() },
      });
      if (offerClaim.count === 0) {
        throw new BadRequestException(
          'Această ofertă nu mai este în așteptare',
        );
      }

      const bookClaim = await tx.userBook.updateMany({
        where: { id: offer.userBookId, isForSale: true },
        data: { isForSale: false, availableForSwap: false },
      });
      if (bookClaim.count === 0) {
        throw new BadRequestException('Cartea nu mai este de vânzare');
      }

      return tx.priceOffer.findUniqueOrThrow({
        where: { id },
        include: INCLUDE_FULL,
      });
    });

    const acceptConversationId = await this.findConversationIdForOffer(id);
    if (acceptConversationId) {
      this.conversations.broadcastPriceOfferUpdate(
        acceptConversationId,
        id,
        'ACCEPTED',
      );
    }
    await this.notifySafe(
      offer.buyerId,
      'PRICE_OFFER_ACCEPTED',
      `${publicName(updated.owner)} a acceptat oferta ta de ${updated.amount.toString()} lei pentru "${updated.userBook.book.title}" - programați o întâlnire`,
      {
        offerId: id,
        ...(acceptConversationId
          ? { conversationId: acceptConversationId }
          : {}),
      },
    );
    await this.notifyOtherPendingBuyers(
      offer.userBookId,
      id,
      'EXCHANGE_BOOK_PENDING',
      `"${updated.userBook.book.title}" este acum într-o vânzare în desfășurare cu altcineva`,
    );

    this.activityLog.record({
      action: 'OFFER_ACCEPTED',
      actorId: userId,
      targetId: offer.buyerId,
      details: {
        offerId: id,
        carte: updated.userBook.book.title,
        suma: Number(updated.amount),
      },
    });

    return this.sanitizeParties(updated);
  }

  async reject(id: string, userId: string) {
    const offer = await this.findForAction(id);
    this.assertIsOwner(offer, userId);
    this.assertStatus(offer, 'PENDING');

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: { status: 'REJECTED' },
      include: INCLUDE_FULL,
    });

    const rejectConversationId = await this.findConversationIdForOffer(id);
    if (rejectConversationId) {
      this.conversations.broadcastPriceOfferUpdate(
        rejectConversationId,
        id,
        'REJECTED',
      );
    }
    await this.notifySafe(
      offer.buyerId,
      'PRICE_OFFER_REJECTED',
      `Oferta ta pentru "${updated.userBook.book.title}" a fost refuzată`,
      {
        offerId: id,
        ...(rejectConversationId
          ? { conversationId: rejectConversationId }
          : {}),
      },
    );

    this.activityLog.record({
      action: 'OFFER_REJECTED',
      actorId: userId,
      targetId: offer.buyerId,
      details: { offerId: id, carte: updated.userBook.book.title },
    });

    return this.sanitizeParties(updated);
  }

  /** Regăsește conversația unde a fost postată oferta, ca notificarea de accept/refuz să te trimită tot acolo. */
  private async findConversationIdForOffer(
    offerId: string,
  ): Promise<string | undefined> {
    const message = await this.prisma.message.findFirst({
      where: { priceOfferId: offerId },
      select: { conversationId: true },
    });
    return message?.conversationId;
  }

  /**
   * Retragere (PENDING, doar cumpărătorul) sau anulare a unei vânzări "în
   * desfășurare" (ACCEPTED, oricare parte - necesită motiv). Mirror exact al
   * exchanges.service.ts#cancel.
   */
  async cancel(id: string, userId: string, dto: CancelExchangeDto = {}) {
    const offer = await this.findForAction(id);

    if (offer.status === 'PENDING') {
      if (offer.buyerId !== userId) {
        throw new ForbiddenException(
          'Doar cel care a făcut oferta o poate anula',
        );
      }
      const updated = await this.prisma.priceOffer.update({
        where: { id },
        data: {
          status: 'CANCELLED',
          cancelReason: dto.reason,
          cancelDetails: dto.details,
          cancelledBy: userId,
        },
        include: INCLUDE_FULL,
      });
      return this.sanitizeParties(updated);
    }

    if (offer.status === 'ACCEPTED') {
      if (offer.buyerId !== userId && offer.ownerId !== userId) {
        throw new ForbiddenException('Nu ești parte în această vânzare');
      }
      if (!dto.reason) {
        throw new BadRequestException('Trebuie să alegi un motiv pentru anulare');
      }
      return this.performCancel(id, offer, dto.reason, dto.details, userId);
    }

    throw new BadRequestException(
      `Acțiunea nu este permisă - oferta are statusul "${offer.status}"`,
    );
  }

  private async performCancel(
    id: string,
    offer: { buyerId: string; ownerId: string; userBookId: string },
    reason: string,
    details: string | undefined,
    cancelledBy: string,
  ) {
    const updated = await this.prisma.$transaction(async (tx) => {
      const claim = await tx.priceOffer.updateMany({
        where: { id, status: 'ACCEPTED' },
        data: {
          status: 'CANCELLED',
          cancelReason: reason,
          cancelDetails: details,
          cancelledBy,
        },
      });
      if (claim.count === 0) {
        throw new BadRequestException('Această vânzare nu mai este în desfășurare');
      }

      await tx.userBook.updateMany({
        where: { id: offer.userBookId },
        data: { isForSale: true, availableForSwap: true },
      });

      return tx.priceOffer.findUniqueOrThrow({
        where: { id },
        include: INCLUDE_FULL,
      });
    });

    const conversationId = await this.findConversationIdForOffer(id);
    if (conversationId) {
      this.conversations.broadcastPriceOfferUpdate(conversationId, id, 'CANCELLED');
    }

    const reasonMessage = CANCEL_REASON_MESSAGES[reason] ?? details ?? 'motiv nespecificat';
    if (cancelledBy === 'system') {
      const timeoutMessage = `Vânzarea pentru "${updated.userBook.book.title}" a expirat automat (${reasonMessage})`;
      await this.notifySafe(offer.buyerId, 'EXCHANGE_CANCELLED', timeoutMessage, { offerId: id });
      await this.notifySafe(offer.ownerId, 'EXCHANGE_CANCELLED', timeoutMessage, { offerId: id });
    } else {
      const otherUserId = cancelledBy === offer.buyerId ? offer.ownerId : offer.buyerId;
      await this.notifySafe(
        otherUserId,
        'EXCHANGE_CANCELLED',
        `Vânzarea pentru "${updated.userBook.book.title}" a fost anulată: ${reasonMessage}`,
        { offerId: id },
      );
    }

    await this.notifyOtherPendingBuyers(
      offer.userBookId,
      id,
      'EXCHANGE_REOPENED',
      `"${updated.userBook.book.title}" e din nou disponibilă (${reasonMessage})`,
    );

    return this.sanitizeParties(updated);
  }

  private async notifyOtherPendingBuyers(
    userBookId: string,
    excludeId: string,
    type: NotificationType,
    message: string,
  ) {
    const siblings = await this.prisma.priceOffer.findMany({
      where: { userBookId, status: 'PENDING', id: { not: excludeId } },
      select: { id: true, buyerId: true },
    });
    for (const sibling of siblings) {
      await this.notifySafe(sibling.buyerId, type, message, { offerId: sibling.id });
    }
  }

  private async rejectSiblingOffers(userBookId: string, excludeId: string, message: string) {
    const siblings = await this.prisma.priceOffer.findMany({
      where: { userBookId, status: 'PENDING', id: { not: excludeId } },
      select: { id: true, buyerId: true },
    });
    if (siblings.length === 0) return;
    await this.prisma.priceOffer.updateMany({
      where: { id: { in: siblings.map((s) => s.id) } },
      data: { status: 'REJECTED', cancelReason: 'book_mismatch', cancelDetails: message },
    });
    for (const sibling of siblings) {
      await this.notifySafe(sibling.buyerId, 'PRICE_OFFER_REJECTED', message, {
        offerId: sibling.id,
      });
    }
  }

  /**
   * Oricare parte marchează vânzarea ca finalizată din partea ei - doar când
   * ambele au apăsat Done cartea chiar se transferă (XP, contoare). Mirror
   * exact al exchanges.service.ts#markDone.
   */
  async markDone(id: string, userId: string) {
    const offer = await this.findOwnedOffer(id, userId);
    this.assertStatus(offer, 'ACCEPTED');
    const isBuyer = userId === offer.buyerId;

    let updated = await this.prisma.priceOffer.update({
      where: { id },
      data: isBuyer ? { buyerDoneAt: new Date() } : { ownerDoneAt: new Date() },
      include: INCLUDE_FULL,
    });

    if (updated.buyerDoneAt && updated.ownerDoneAt) {
      updated = await this.prisma.$transaction(async (tx) => {
        await tx.user.update({
          where: { id: updated.ownerId },
          data: {
            booksSharedCount: { increment: 1 },
            xp: { increment: XP_SALE_COMPLETED },
          },
        });
        await tx.user.update({
          where: { id: updated.buyerId },
          data: { booksReceivedCount: { increment: 1 } },
        });
        await tx.userBook.update({
          where: { id: updated.userBookId },
          data: { permanentlyTransferred: true, isForSale: false, availableForSwap: false },
        });

        return tx.priceOffer.update({
          where: { id },
          data: { status: 'COMPLETED' },
          include: INCLUDE_FULL,
        });
      });

      const conversationId = await this.findConversationIdForOffer(id);
      if (conversationId) {
        this.conversations.broadcastPriceOfferUpdate(conversationId, id, 'COMPLETED');
      }
      const doneMessage = `Vânzarea pentru "${updated.userBook.book.title}" a fost finalizată`;
      await this.notifySafe(updated.buyerId, 'EXCHANGE_COMPLETED', doneMessage, { offerId: id });
      await this.notifySafe(updated.ownerId, 'EXCHANGE_COMPLETED', doneMessage, { offerId: id });
      await this.rejectSiblingOffers(
        updated.userBookId,
        id,
        `"${updated.userBook.book.title}" a fost deja vândută altcuiva`,
      );
    } else {
      const otherUserId = isBuyer ? updated.ownerId : updated.buyerId;
      const actorName = publicName(isBuyer ? updated.buyer : updated.owner);
      await this.notifySafe(
        otherUserId,
        'EXCHANGE_DONE_PENDING_CONFIRMATION',
        `${actorName} a marcat vânzarea pentru "${updated.userBook.book.title}" ca finalizată - confirmă și tu`,
        { offerId: id },
      );
    }

    this.activityLog.record({
      action:
        updated.status === 'COMPLETED' ? 'SALE_COMPLETED' : 'SALE_MARKED_DONE',
      actorId: userId,
      targetId: isBuyer ? updated.ownerId : updated.buyerId,
      details: { offerId: id, carte: updated.userBook.book.title },
    });

    return this.sanitizeParties(updated);
  }

  async disputeDone(id: string, userId: string) {
    const offer = await this.findOwnedOffer(id, userId);
    this.assertStatus(offer, 'ACCEPTED');
    const isBuyer = userId === offer.buyerId;
    const otherAlreadyDone = isBuyer ? offer.ownerDoneAt : offer.buyerDoneAt;
    if (!otherAlreadyDone) {
      throw new BadRequestException('Cealaltă parte nu a marcat vânzarea ca finalizată');
    }

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: isBuyer ? { ownerDoneAt: null } : { buyerDoneAt: null },
      include: INCLUDE_FULL,
    });

    const otherUserId = isBuyer ? updated.ownerId : updated.buyerId;
    const actorName = publicName(isBuyer ? updated.buyer : updated.owner);
    await this.notifySafe(
      otherUserId,
      'EXCHANGE_DONE_DISPUTED',
      `${actorName} nu a confirmat finalizarea vânzării pentru "${updated.userBook.book.title}"`,
      { offerId: id },
    );

    return this.sanitizeParties(updated);
  }

  async proposeMeeting(id: string, userId: string, dto: SetMeetingDto) {
    const offer = await this.findOwnedOffer(id, userId);
    this.assertStatus(offer, 'ACCEPTED');

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: {
        meetingTime: new Date(dto.meetingTime),
        meetingLocation: dto.meetingLocation,
        meetingProposedBy: userId,
        meetingAcceptedAt: null,
      },
      include: INCLUDE_FULL,
    });

    const isBuyer = userId === updated.buyerId;
    const otherUserId = isBuyer ? updated.ownerId : updated.buyerId;
    const actorName = publicName(isBuyer ? updated.buyer : updated.owner);
    await this.notifySafe(
      otherUserId,
      'EXCHANGE_MEETING_PROPOSED',
      `${actorName} a propus o întâlnire pentru "${updated.userBook.book.title}" - confirmă sau propune altă oră`,
      { offerId: updated.id },
    );

    return this.sanitizeParties(updated);
  }

  async acceptMeeting(id: string, userId: string) {
    const offer = await this.findOwnedOffer(id, userId);
    this.assertStatus(offer, 'ACCEPTED');
    if (!offer.meetingTime || !offer.meetingProposedBy) {
      throw new BadRequestException('Nu există nicio întâlnire propusă');
    }
    if (offer.meetingProposedBy === userId) {
      throw new BadRequestException(
        'Așteaptă răspunsul celeilalte părți la propunerea ta',
      );
    }

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: { meetingAcceptedAt: new Date() },
      include: INCLUDE_FULL,
    });

    await this.notifySafe(
      offer.meetingProposedBy,
      'EXCHANGE_MEETING_ACCEPTED',
      `Întâlnirea pentru "${updated.userBook.book.title}" a fost confirmată`,
      { offerId: id },
    );

    return this.sanitizeParties(updated);
  }

  async declineMeeting(id: string, userId: string) {
    return this.resetMeeting(
      id,
      userId,
      'EXCHANGE_MEETING_DECLINED',
      (name, title) => `${name ?? 'Cineva'} a refuzat ora propusă pentru "${title}" - propune o oră nouă`,
    );
  }

  async postpone(id: string, userId: string) {
    return this.resetMeeting(
      id,
      userId,
      'EXCHANGE_POSTPONED',
      (name, title) => `${name ?? 'Cineva'} a amânat vânzarea pentru "${title}" - propuneți o nouă întâlnire`,
    );
  }

  private async resetMeeting(
    id: string,
    userId: string,
    type: NotificationType,
    messageFor: (actorName: string | null, bookTitle: string) => string,
  ) {
    const offer = await this.findOwnedOffer(id, userId);
    this.assertStatus(offer, 'ACCEPTED');
    if (!offer.meetingTime) {
      throw new BadRequestException('Nu există nicio întâlnire programată');
    }

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: {
        meetingTime: null,
        meetingLocation: null,
        meetingProposedBy: null,
        meetingAcceptedAt: null,
      },
      include: INCLUDE_FULL,
    });

    const isBuyer = userId === updated.buyerId;
    const otherUserId = isBuyer ? updated.ownerId : updated.buyerId;
    const actorName = publicName(isBuyer ? updated.buyer : updated.owner);
    await this.notifySafe(
      otherUserId,
      type,
      messageFor(actorName, updated.userBook.book.title),
      { offerId: id },
    );

    return this.sanitizeParties(updated);
  }

  async shareContact(id: string, userId: string, dto: ShareContactDto) {
    const offer = await this.findOwnedOffer(id, userId);
    this.assertStatus(offer, 'ACCEPTED');
    const isBuyer = userId === offer.buyerId;

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: isBuyer
        ? { buyerContactPhone: dto.phone ?? null, buyerContactSharedAt: new Date() }
        : { ownerContactPhone: dto.phone ?? null, ownerContactSharedAt: new Date() },
      include: INCLUDE_FULL,
    });

    const otherUserId = isBuyer ? updated.ownerId : updated.buyerId;
    const actorName = publicName(isBuyer ? updated.buyer : updated.owner);
    await this.notifySafe(
      otherUserId,
      'EXCHANGE_CONTACT_SHARED',
      `${actorName} ți-a trimis detaliile de contact pentru vânzare`,
      { offerId: id },
    );

    return this.sanitizeParties(updated);
  }

  async acknowledgeSafety(id: string, userId: string) {
    const offer = await this.findOwnedOffer(id, userId);
    this.assertStatus(offer, 'ACCEPTED');
    const isBuyer = userId === offer.buyerId;

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: isBuyer ? { buyerSafetyAckAt: new Date() } : { ownerSafetyAckAt: new Date() },
      include: INCLUDE_FULL,
    });

    if (updated.buyerSafetyAckAt && updated.ownerSafetyAckAt) {
      const message = `Sunteți gata pentru întâlnire - "${updated.userBook.book.title}"`;
      await this.notifySafe(updated.buyerId, 'EXCHANGE_READY', message, { offerId: id });
      await this.notifySafe(updated.ownerId, 'EXCHANGE_READY', message, { offerId: id });
    }

    return this.sanitizeParties(updated);
  }

  /** Generează un fișier .ics pentru întâlnirea de vânzare. Mirror al exchanges.service.ts#generateIcs. */
  async generateIcs(id: string, userId: string): Promise<string> {
    const offer = await this.findOwnedOffer(id, userId);
    if (!offer.meetingTime) {
      throw new BadRequestException(
        'Nu a fost programată încă o întâlnire pentru această vânzare',
      );
    }

    const start = offer.meetingTime;
    const end = new Date(start.getTime() + 60 * 60 * 1000);

    const escape = (text: string) =>
      text
        .replace(/\\/g, '\\\\')
        .replace(/,/g, '\\,')
        .replace(/;/g, '\\;')
        .replace(/\n/g, '\\n');

    const formatDate = (date: Date) =>
      date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';

    const buyerName = offer.buyer.name ?? 'Cineva';
    const ownerName = offer.owner.name ?? 'Cineva';
    const bookTitle = offer.userBook.book.title;

    const summary = 'Întâlnire vânzare carte';
    const description = `${buyerName} se întâlnește cu ${ownerName} pentru a cumpăra cartea „${bookTitle}" (${offer.amount.toString()} lei)`;

    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ShelfShare//Offer//RO',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      `UID:${offer.id}@shelfshare`,
      `DTSTAMP:${formatDate(new Date())}`,
      `DTSTART:${formatDate(start)}`,
      `DTEND:${formatDate(end)}`,
      `SUMMARY:${escape(summary)}`,
      `LOCATION:${escape(offer.meetingLocation ?? '')}`,
      `DESCRIPTION:${escape(description)}`,
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  /**
   * Contra-ofertă (Batch 11): oricare parte poate propune un preț nou.
   * Original devine REJECTED (nu are sens „PENDING dublu"), iar noua ofertă
   * are rolurile buyer/owner INVERSATE față de original - astfel cealaltă
   * parte devine „ownerul deciziei" și poate folosi fluxul standard
   * accept/reject/counter fără cazuri speciale.
   *
   * Noua ofertă se postează ca mesaj în aceeași conversație (același
   * mecanism ca la createOffer), iar cealaltă parte primește notificare.
   */
  async counter(id: string, userId: string, dto: CounterOfferDto) {
    const original = await this.findForAction(id);
    if (original.buyerId !== userId && original.ownerId !== userId) {
      throw new ForbiddenException(
        'Doar participanții la ofertă pot face contra-ofertă',
      );
    }
    this.assertStatus(original, 'PENDING');

    const originalWithBook = await this.prisma.priceOffer.findUnique({
      where: { id },
      include: { userBook: { include: { book: true } } },
    });
    if (!originalWithBook) {
      throw new NotFoundException('Oferta nu a fost găsită');
    }

    // Rolurile se inversează: „buyerId" al noii oferte = cel care propune
    // (userId curent). Astfel, decizia rămâne mereu la ownerId.
    const newBuyerId = userId;
    const newOwnerId =
      userId === original.buyerId ? original.ownerId : original.buyerId;

    const counterOffer = await this.prisma.$transaction(async (tx) => {
      await tx.priceOffer.update({
        where: { id },
        data: { status: 'REJECTED' },
      });
      return tx.priceOffer.create({
        data: {
          buyerId: newBuyerId,
          ownerId: newOwnerId,
          userBookId: original.userBookId,
          amount: dto.amount,
          message: dto.message,
          expiresAt: new Date(Date.now() + OFFER_EXPIRY_DAYS * 86_400_000),
        },
        include: INCLUDE_FULL,
      });
    });

    // Postează contra-oferta ca mesaj în conversația existentă (dacă găsită)
    // sau creează una - același comportament ca la createOffer.
    const conversation = await this.conversations.findOrCreateConversation(
      newBuyerId,
      newOwnerId,
    );
    this.conversations.broadcastPriceOfferUpdate(
      conversation.id,
      id,
      'REJECTED',
    );
    await this.conversations.createPriceOfferMessage(
      conversation.id,
      newBuyerId,
      counterOffer.id,
      `Contra-ofertă: ${dto.amount} lei pentru "${originalWithBook.userBook.book.title}"`,
    );

    await this.notifySafe(
      newOwnerId,
      'PRICE_OFFER_RECEIVED',
      `Ai primit o contra-ofertă de ${dto.amount} lei pentru "${originalWithBook.userBook.book.title}"`,
      { offerId: counterOffer.id, conversationId: conversation.id },
    );

    this.activityLog.record({
      action: 'OFFER_COUNTERED',
      actorId: userId,
      targetId: newOwnerId,
      details: {
        offerId: counterOffer.id,
        carte: originalWithBook.userBook.book.title,
        suma: dto.amount,
      },
    });

    return this.sanitizeParties(counterOffer);
  }

  /**
   * Timeout-ul de 7 zile - o vânzare ACCEPTED care nu ajunge la Done în 7
   * zile de la acceptare se anulează automat. Mirror exact al
   * exchanges.service.ts#expireStaleAccepted.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async expireStaleAccepted(): Promise<void> {
    const cutoff = new Date(Date.now() - SALE_TIMEOUT_DAYS * 86_400_000);
    const stale = await this.prisma.priceOffer.findMany({
      where: { status: 'ACCEPTED', acceptedAt: { lt: cutoff } },
      select: { id: true },
    });
    if (stale.length === 0) {
      return;
    }

    this.logger.log(`Expir ${stale.length} vânzări ACCEPTED peste ${SALE_TIMEOUT_DAYS} zile`);
    for (const { id } of stale) {
      try {
        const offer = await this.prisma.priceOffer.findUnique({ where: { id } });
        if (!offer || offer.status !== 'ACCEPTED') continue;
        await this.performCancel(id, offer, 'expired', undefined, 'system');
      } catch (error) {
        this.logger.error(`Nu am putut expira vânzarea ${id}`, error);
      }
    }
  }

  private async findForAction(id: string) {
    const offer = await this.prisma.priceOffer.findUnique({ where: { id } });
    if (!offer) {
      throw new NotFoundException('Oferta nu a fost găsită');
    }
    return this.expireIfStale(offer);
  }

  /**
   * Expirare "leneșă" - vezi comentariul de pe PriceOffer.expiresAt în
   * schema.prisma. Verificată la fiecare citire, nu printr-un job separat.
   */
  private async expireIfStale<
    T extends { id: string; status: string; expiresAt: Date | null },
  >(offer: T): Promise<T> {
    if (
      offer.status !== 'PENDING' ||
      !offer.expiresAt ||
      offer.expiresAt > new Date()
    ) {
      return offer;
    }
    await this.prisma.priceOffer.update({
      where: { id: offer.id },
      data: { status: 'EXPIRED' },
    });
    return { ...offer, status: 'EXPIRED' };
  }

  private async findOwnedOffer(id: string, userId: string) {
    const offer = await this.prisma.priceOffer.findUnique({
      where: { id },
      include: INCLUDE_FULL,
    });
    if (!offer) {
      throw new NotFoundException('Oferta nu a fost găsită');
    }
    if (offer.buyerId !== userId && offer.ownerId !== userId) {
      throw new ForbiddenException('Nu ești parte în această vânzare');
    }
    return this.sanitizeParties(await this.expireIfStale(offer));
  }

  private assertIsOwner(offer: { ownerId: string }, userId: string) {
    if (offer.ownerId !== userId) {
      throw new ForbiddenException('Doar proprietarul cărții poate face asta');
    }
  }

  private assertStatus(offer: { status: string }, expected: string) {
    if (offer.status !== expected) {
      throw new BadRequestException(
        `Acțiunea nu este permisă - oferta are statusul "${offer.status}"`,
      );
    }
  }
}

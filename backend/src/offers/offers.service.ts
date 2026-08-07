import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ConversationsService } from '../chat/conversations.service';
import { NotificationType } from '@prisma/client';
import { CreateOfferDto } from './dto/create-offer.dto';
import { CounterOfferDto } from './dto/counter-offer.dto';
import { publicName } from '../common/utils/user-visibility';
import { XP_SALE_COMPLETED } from '../common/utils/xp';

// Offer Expiration (Milestone 3) - vezi comentariul din exchanges.service.ts.
const OFFER_EXPIRY_DAYS = 7;

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
    if (!userBook.isForSale) {
      throw new BadRequestException('Această carte nu este de vânzare');
    }
    if (!userBook.isNegotiable) {
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

    return this.sanitizeParties(created);
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

  private async expireStalePending(where: {
    buyerId?: string;
    ownerId?: string;
  }) {
    await this.prisma.priceOffer.updateMany({
      where: { ...where, status: 'PENDING', expiresAt: { lt: new Date() } },
      data: { status: 'EXPIRED' },
    });
  }

  async accept(id: string, userId: string) {
    const offer = await this.findForAction(id);
    this.assertIsOwner(offer, userId);
    this.assertStatus(offer, 'PENDING');

    const updated = await this.prisma.$transaction(async (tx) => {
      // Atomic guards prevent two concurrent accept() calls (e.g. on two
      // different pending offers for the same book) from both succeeding.
      const offerClaim = await tx.priceOffer.updateMany({
        where: { id, status: 'PENDING' },
        data: { status: 'ACCEPTED' },
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

      await tx.user.update({
        where: { id: offer.ownerId },
        data: {
          booksSharedCount: { increment: 1 },
          xp: { increment: XP_SALE_COMPLETED },
        },
      });
      await tx.user.update({
        where: { id: offer.buyerId },
        data: { booksReceivedCount: { increment: 1 } },
      });

      return tx.priceOffer.findUniqueOrThrow({
        where: { id },
        include: INCLUDE_FULL,
      });
    });

    const acceptConversationId = await this.findConversationIdForOffer(id);
    await this.notifySafe(
      offer.buyerId,
      'PRICE_OFFER_ACCEPTED',
      `Oferta ta pentru "${updated.userBook.book.title}" a fost acceptată`,
      {
        offerId: id,
        ...(acceptConversationId
          ? { conversationId: acceptConversationId }
          : {}),
      },
    );

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

  async cancel(id: string, userId: string) {
    const offer = await this.findForAction(id);
    if (offer.buyerId !== userId) {
      throw new ForbiddenException(
        'Doar cel care a făcut oferta o poate anula',
      );
    }
    this.assertStatus(offer, 'PENDING');

    const updated = await this.prisma.priceOffer.update({
      where: { id },
      data: { status: 'CANCELLED' },
      include: INCLUDE_FULL,
    });
    return this.sanitizeParties(updated);
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

    return this.sanitizeParties(counterOffer);
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

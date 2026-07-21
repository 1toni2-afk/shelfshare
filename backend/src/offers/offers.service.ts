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
import { CreateOfferDto } from './dto/create-offer.dto';

const INCLUDE_FULL = {
  userBook: { include: { book: true } },
  buyer: {
    select: {
      id: true,
      name: true,
      city: true,
      rating: true,
      profileImage: true,
    },
  },
  owner: {
    select: {
      id: true,
      name: true,
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
      },
      include: INCLUDE_FULL,
    });

    const buyer = await this.prisma.user.findUnique({ where: { id: buyerId } });
    await this.notifySafe(
      userBook.userId,
      'PRICE_OFFER_RECEIVED',
      `${buyer?.name ?? 'Un utilizator'} ți-a oferit ${dto.amount} lei pentru cartea ta "${userBook.book.title}"`,
      { offerId: created.id },
    );

    return created;
  }

  getSentOffers(userId: string) {
    return this.prisma.priceOffer.findMany({
      where: { buyerId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
  }

  getReceivedOffers(userId: string) {
    return this.prisma.priceOffer.findMany({
      where: { ownerId: userId },
      include: INCLUDE_FULL,
      orderBy: { createdAt: 'desc' },
    });
  }

  async accept(id: string, userId: string) {
    const offer = await this.findForAction(id);
    this.assertIsOwner(offer, userId);
    this.assertStatus(offer, 'PENDING');

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.userBook.update({
        where: { id: offer.userBookId },
        data: { isForSale: false, availableForSwap: false },
      });

      return tx.priceOffer.update({
        where: { id },
        data: { status: 'ACCEPTED' },
        include: INCLUDE_FULL,
      });
    });

    await this.notifySafe(
      offer.buyerId,
      'PRICE_OFFER_ACCEPTED',
      `Oferta ta pentru "${updated.userBook.book.title}" a fost acceptată`,
      { offerId: id },
    );

    return updated;
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

    await this.notifySafe(
      offer.buyerId,
      'PRICE_OFFER_REJECTED',
      `Oferta ta pentru "${updated.userBook.book.title}" a fost refuzată`,
      { offerId: id },
    );

    return updated;
  }

  async cancel(id: string, userId: string) {
    const offer = await this.findForAction(id);
    if (offer.buyerId !== userId) {
      throw new ForbiddenException(
        'Doar cel care a făcut oferta o poate anula',
      );
    }
    this.assertStatus(offer, 'PENDING');

    return this.prisma.priceOffer.update({
      where: { id },
      data: { status: 'CANCELLED' },
      include: INCLUDE_FULL,
    });
  }

  private async findForAction(id: string) {
    const offer = await this.prisma.priceOffer.findUnique({ where: { id } });
    if (!offer) {
      throw new NotFoundException('Oferta nu a fost găsită');
    }
    return offer;
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

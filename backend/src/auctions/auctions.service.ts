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
import { CreateAuctionDto } from './dto/create-auction.dto';
import { PlaceBidDto } from './dto/place-bid.dto';
import { publicName } from '../common/utils/user-visibility';
import { awardXp, XP_SALE_COMPLETED } from '../common/utils/xp';

// Anti-sniping: un bid plasat în ultimele 5 minute împinge termenul cu încă
// 5 minute, cât timp tot vin bid-uri târzii - descurajează "sniping"-ul de
// ultimă secundă fără să impună un algoritm mai complex (ex. proxy bidding).
const ANTI_SNIPE_WINDOW_MS = 5 * 60_000;
const ANTI_SNIPE_EXTENSION_MS = 5 * 60_000;

const OWNER_SELECT = {
  id: true,
  name: true,
  username: true,
  nameVisible: true,
  city: true,
  rating: true,
  profileImage: true,
} as const;

const BIDDER_SELECT = {
  id: true,
  name: true,
  username: true,
  nameVisible: true,
  profileImage: true,
} as const;

const INCLUDE_FULL = {
  userBook: { include: { book: true, user: { select: OWNER_SELECT } } },
  highestBidder: { select: BIDDER_SELECT },
  bids: { include: { bidder: { select: BIDDER_SELECT } }, orderBy: { createdAt: 'asc' as const } },
  _count: { select: { watches: true } },
};

@Injectable()
export class AuctionsService {
  private readonly logger = new Logger(AuctionsService.name);

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

  async createAuction(sellerId: string, userBookId: string, dto: CreateAuctionDto) {
    const userBook = await this.prisma.userBook.findUnique({
      where: { id: userBookId },
      include: { auction: true },
    });
    if (!userBook) {
      throw new NotFoundException('Cartea nu a fost găsită');
    }
    if (userBook.userId !== sellerId) {
      throw new ForbiddenException('Doar proprietarul cărții poate începe o licitație');
    }
    if (userBook.auction) {
      throw new BadRequestException('Această carte are deja o licitație');
    }
    if (userBook.photos.length === 0) {
      throw new BadRequestException('Adaugă cel puțin o poză înainte de a începe o licitație');
    }
    if (dto.reservePrice != null && dto.reservePrice < dto.startingPrice) {
      throw new BadRequestException(
        'Prețul de rezervă nu poate fi mai mic decât prețul de pornire',
      );
    }
    if (dto.buyNowPrice != null && dto.buyNowPrice <= dto.startingPrice) {
      throw new BadRequestException(
        'Prețul "Cumpără acum" trebuie să fie mai mare decât prețul de pornire',
      );
    }

    const endsAt = new Date(Date.now() + dto.durationHours * 3_600_000);

    const created = await this.prisma.$transaction(async (tx) => {
      const auction = await tx.auction.create({
        data: {
          userBookId,
          startingPrice: dto.startingPrice,
          reservePrice: dto.reservePrice,
          buyNowPrice: dto.buyNowPrice,
          currentPrice: dto.startingPrice,
          endsAt,
        },
      });
      await tx.userBook.update({
        where: { id: userBookId },
        data: { isAuction: true, isForSale: false, availableForSwap: false },
      });
      return auction;
    });

    return this.getAuction(created.id, sellerId);
  }

  async getAuction(id: string, requestingUserId?: string) {
    const auction = await this.findAndExpireIfStale(id);
    const isSeller = auction.userBook.userId === requestingUserId;
    const isWatching = requestingUserId
      ? (await this.prisma.auctionWatch.findUnique({
          where: { auctionId_userId: { auctionId: id, userId: requestingUserId } },
        })) != null
      : false;

    return {
      ...this.serialize(auction),
      bids: this.anonymizeBids(auction.bids, isSeller),
      isSeller,
      isWatching,
      canBuyNow: auction.buyNowPrice != null && auction.bids.length === 0 && auction.status === 'ACTIVE',
    };
  }

  async placeBid(bidderId: string, auctionId: string, dto: PlaceBidDto) {
    const auction = await this.findAndExpireIfStale(auctionId);
    if (auction.userBook.userId === bidderId) {
      throw new BadRequestException('Nu poți licita la propria licitație');
    }
    if (auction.status !== 'ACTIVE') {
      throw new BadRequestException('Această licitație s-a încheiat');
    }
    if (dto.amount <= Number(auction.currentPrice)) {
      throw new BadRequestException(
        `Oferta trebuie să fie mai mare decât prețul curent (${auction.currentPrice} lei)`,
      );
    }

    const previousHighestBidderId = auction.highestBidderId;
    const now = Date.now();
    const shouldExtend = auction.endsAt.getTime() - now < ANTI_SNIPE_WINDOW_MS;
    const newEndsAt = shouldExtend ? new Date(now + ANTI_SNIPE_EXTENSION_MS) : auction.endsAt;

    await this.prisma.$transaction([
      this.prisma.bid.create({
        data: { auctionId, bidderId, amount: dto.amount },
      }),
      this.prisma.auction.update({
        where: { id: auctionId },
        data: { currentPrice: dto.amount, highestBidderId: bidderId, endsAt: newEndsAt },
      }),
    ]);

    if (previousHighestBidderId && previousHighestBidderId !== bidderId) {
      await this.notifySafe(
        previousHighestBidderId,
        'OUTBID',
        `Ai fost depășit la licitația pentru "${auction.userBook.book.title}" - prețul curent e acum ${dto.amount} lei`,
        { auctionId },
      );
    }

    return this.getAuction(auctionId, bidderId);
  }

  async buyNow(buyerId: string, auctionId: string) {
    const auction = await this.findAndExpireIfStale(auctionId);
    if (auction.userBook.userId === buyerId) {
      throw new BadRequestException('Nu poți cumpăra propria carte');
    }
    if (auction.status !== 'ACTIVE') {
      throw new BadRequestException('Această licitație s-a încheiat');
    }
    if (auction.buyNowPrice == null) {
      throw new BadRequestException('Această licitație nu are opțiunea "Cumpără acum"');
    }
    if (auction.bids.length > 0) {
      throw new BadRequestException(
        '"Cumpără acum" nu mai este disponibil - licitația are deja oferte',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.bid.create({
        data: { auctionId, bidderId: buyerId, amount: auction.buyNowPrice! },
      });
      await tx.auction.update({
        where: { id: auctionId },
        data: {
          currentPrice: auction.buyNowPrice!,
          highestBidderId: buyerId,
          status: 'ENDED',
        },
      });
    });

    await this.finalizeWin(auctionId, buyerId);
    return this.getAuction(auctionId, buyerId);
  }

  async watch(userId: string, auctionId: string) {
    await this.findAndExpireIfStale(auctionId);
    await this.prisma.auctionWatch.upsert({
      where: { auctionId_userId: { auctionId, userId } },
      create: { auctionId, userId },
      update: {},
    });
    return { message: 'Licitație urmărită' };
  }

  async unwatch(userId: string, auctionId: string) {
    await this.prisma.auctionWatch
      .delete({ where: { auctionId_userId: { auctionId, userId } } })
      .catch(() => {});
    return { message: 'Licitație neurmărită' };
  }

  async getMyBids(userId: string) {
    const bids = await this.prisma.bid.findMany({
      where: { bidderId: userId },
      distinct: ['auctionId'],
      orderBy: { createdAt: 'desc' },
      select: { auctionId: true },
    });
    const auctions = await Promise.all(
      bids.map(async (b) => {
        await this.findAndExpireIfStale(b.auctionId);
        return this.getAuction(b.auctionId, userId);
      }),
    );
    return auctions;
  }

  async getMyWatches(userId: string) {
    const watches = await this.prisma.auctionWatch.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: { auctionId: true },
    });
    return Promise.all(watches.map((w) => this.getAuction(w.auctionId, userId)));
  }

  /**
   * Expirare "leneșă" - vezi comentariul de pe PriceOffer.expiresAt din
   * schema.prisma. Verificată la fiecare citire, nu printr-un job separat.
   * Spre deosebire de PriceOffer/ExchangeRequest, încheierea unei licitații
   * are un efect secundar (alegerea câștigătorului + notificări), nu doar
   * o schimbare de status.
   */
  private async findAndExpireIfStale(id: string) {
    const auction = await this.prisma.auction.findUnique({
      where: { id },
      include: INCLUDE_FULL,
    });
    if (!auction) {
      throw new NotFoundException('Licitația nu a fost găsită');
    }
    if (auction.status !== 'ACTIVE' || auction.endsAt > new Date()) {
      return auction;
    }

    await this.prisma.auction.update({
      where: { id },
      data: { status: 'ENDED' },
    });

    const reserveMet =
      auction.reservePrice == null || Number(auction.currentPrice) >= Number(auction.reservePrice);

    if (auction.highestBidderId && reserveMet) {
      await this.finalizeWin(id, auction.highestBidderId);
    } else {
      await this.notifySafe(
        auction.userBook.userId,
        'AUCTION_ENDED',
        auction.highestBidderId
          ? `Licitația pentru "${auction.userBook.book.title}" s-a încheiat fără să atingă prețul de rezervă`
          : `Licitația pentru "${auction.userBook.book.title}" s-a încheiat fără nicio ofertă`,
        { auctionId: id },
      );
    }

    return { ...auction, status: 'ENDED' as const };
  }

  /** Marchează cartea ca vândută (aceleași efecte ca o ofertă de preț acceptată) și notifică ambele părți. */
  private async finalizeWin(auctionId: string, winnerId: string) {
    const auction = await this.prisma.auction.findUnique({
      where: { id: auctionId },
      include: { userBook: { include: { book: true } } },
    });
    if (!auction) return;

    await this.prisma.$transaction([
      this.prisma.userBook.update({
        where: { id: auction.userBookId },
        data: { isForSale: false, availableForSwap: false, isAuction: false },
      }),
      this.prisma.user.update({
        where: { id: auction.userBook.userId },
        data: { booksSharedCount: { increment: 1 } },
      }),
      this.prisma.user.update({
        where: { id: winnerId },
        data: { booksReceivedCount: { increment: 1 } },
      }),
    ]);
    await awardXp(this.prisma, auction.userBook.userId, XP_SALE_COMPLETED);

    await this.notifySafe(
      winnerId,
      'AUCTION_WON',
      `Ai câștigat licitația pentru "${auction.userBook.book.title}" cu ${auction.currentPrice} lei`,
      { auctionId },
    );
    await this.notifySafe(
      auction.userBook.userId,
      'AUCTION_ENDED',
      `Licitația pentru "${auction.userBook.book.title}" s-a încheiat - a câștigat cineva cu ${auction.currentPrice} lei`,
      { auctionId },
    );
  }

  /** Ofertele sunt anonime pentru ceilalți licitatori ("Ofertant #N", ordinea primei apariții) - vizibile integral doar pentru vânzător. */
  private anonymizeBids(
    bids: Array<{
      id: string;
      amount: unknown;
      createdAt: Date;
      bidderId: string;
      bidder: { id: string; name: string | null; username: string | null; nameVisible: boolean; profileImage: string | null };
    }>,
    isSeller: boolean,
  ) {
    if (isSeller) {
      return bids
        .slice()
        .reverse()
        .map((b) => ({
          id: b.id,
          amount: b.amount,
          createdAt: b.createdAt,
          bidder: { ...b.bidder, name: publicName(b.bidder) },
        }));
    }

    const ordinalByBidder = new Map<string, number>();
    for (const bid of bids) {
      if (!ordinalByBidder.has(bid.bidderId)) {
        ordinalByBidder.set(bid.bidderId, ordinalByBidder.size + 1);
      }
    }

    return bids
      .slice()
      .reverse()
      .map((b) => ({
        id: b.id,
        amount: b.amount,
        createdAt: b.createdAt,
        bidder: { label: `Ofertant #${ordinalByBidder.get(b.bidderId)}` },
      }));
  }

  private serialize(auction: {
    id: string;
    startingPrice: unknown;
    reservePrice: unknown;
    buyNowPrice: unknown;
    currentPrice: unknown;
    endsAt: Date;
    status: string;
    createdAt: Date;
    highestBidder: { id: string; name: string | null; username: string | null; nameVisible: boolean; profileImage: string | null } | null;
    userBook: { id: string; userId: string; book: unknown; user: { name: string | null; nameVisible: boolean; [k: string]: unknown } };
    _count: { watches: number };
  }) {
    return {
      id: auction.id,
      startingPrice: auction.startingPrice,
      reservePrice: auction.reservePrice,
      buyNowPrice: auction.buyNowPrice,
      currentPrice: auction.currentPrice,
      endsAt: auction.endsAt,
      status: auction.status,
      createdAt: auction.createdAt,
      reserveMet:
        auction.reservePrice == null ||
        Number(auction.currentPrice) >= Number(auction.reservePrice),
      watchersCount: auction._count.watches,
      highestBidder: auction.highestBidder
        ? { ...auction.highestBidder, name: publicName(auction.highestBidder) }
        : null,
      userBook: {
        ...auction.userBook,
        user: { ...auction.userBook.user, name: publicName(auction.userBook.user) },
      },
    };
  }
}

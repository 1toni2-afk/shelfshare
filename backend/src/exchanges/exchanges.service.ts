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
import { StorageService } from '../storage/storage.service';
import { NotificationType, Prisma } from '@prisma/client';
import { CreateExchangeRequestDto } from './dto/create-exchange-request.dto';
import { RateExchangeDto } from './dto/rate-exchange.dto';
import { SetMeetingDto } from './dto/set-meeting.dto';
import { CancelExchangeDto } from './dto/cancel-exchange.dto';
import { ShareContactDto } from './dto/share-contact.dto';
import { DoneExchangeDto } from './dto/done-exchange.dto';
import { publicName } from '../common/utils/user-visibility';
import {
  awardXp,
  XP_EXCHANGE_COMPLETED,
  XP_REVIEW_WRITTEN,
} from '../common/utils/xp';

// Offer Expiration (Milestone 3) - o cerere PENDING neatinsă expiră automat
// după atâtea zile, ca să nu rămână la nesfârșit "în așteptare" fără răspuns.
const OFFER_EXPIRY_DAYS = 7;

// Timeout-ul schimbului "în desfășurare" (Milestone: Exchange flow v2) - dacă
// nu ajunge la Done în atâtea zile de la acceptare, se anulează automat.
const EXCHANGE_TIMEOUT_DAYS = 7;

// "Condition Photos" (feature backlog #14) - suficient să documenteze coperta
// + eventuale defecte, fără să transforme asta într-o galerie foto.
const MAX_CONDITION_PHOTOS = 4;

const CANCEL_REASON_MESSAGES: Record<string, string> = {
  no_show: 'cealaltă persoană nu s-a prezentat',
  book_mismatch: 'cartea nu a corespuns așteptărilor',
  changed_mind: 's-a răzgândit',
  other: 'motiv nespecificat',
  expired: 'termenul de 7 zile a expirat fără nicio confirmare',
};

const INCLUDE_FULL = {
  requestedBook: { include: { book: true } },
  offeredBook: { include: { book: true } },
  additionalOfferedBooks: { include: { userBook: { include: { book: true } } } },
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
    private conversations: ConversationsService,
    private listingScore: ListingScoreService,
    private storage: StorageService,
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
      requesterConditionPhotos: string[];
      ownerConditionPhotos: string[];
    },
  >(request: T): T {
    return {
      ...request,
      requester: { ...request.requester, name: publicName(request.requester) },
      owner: { ...request.owner, name: publicName(request.owner) },
      requesterConditionPhotos: request.requesterConditionPhotos.map((p) =>
        this.storage.getPublicUrl(p),
      ),
      ownerConditionPhotos: request.ownerConditionPhotos.map((p) =>
        this.storage.getPublicUrl(p),
      ),
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

    let offeredBook: {
      userId: string;
      availableForSwap: boolean;
      book: { title: string };
    } | null = null;
    if (dto.offeredBookId) {
      offeredBook = await this.prisma.userBook.findUnique({
        where: { id: dto.offeredBookId },
        select: {
          userId: true,
          availableForSwap: true,
          book: { select: { title: true } },
        },
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

    // Feature backlog #17: pachetul de cărți suplimentare oferite - au
    // nevoie de aceleași verificări ca `offeredBookId` (proprietate +
    // disponibilitate), plus să nu se suprapună cu cartea cerută sau cu
    // prima carte oferită.
    const additionalIds = dto.additionalOfferedBookIds ?? [];
    if (additionalIds.length > 0 && !dto.offeredBookId) {
      throw new BadRequestException(
        'Trebuie să alegi mai întâi o carte principală de oferit',
      );
    }
    if (
      additionalIds.some(
        (id) => id === dto.requestedBookId || id === dto.offeredBookId,
      )
    ) {
      throw new BadRequestException(
        'Cărțile din pachet trebuie să fie distincte între ele',
      );
    }
    const additionalBooks =
      additionalIds.length > 0
        ? await this.prisma.userBook.findMany({
            where: { id: { in: additionalIds } },
            select: { id: true, userId: true, availableForSwap: true },
          })
        : [];
    if (additionalBooks.length !== additionalIds.length) {
      throw new NotFoundException(
        'O carte din pachetul oferit nu a fost găsită',
      );
    }
    for (const book of additionalBooks) {
      if (book.userId !== requesterId) {
        throw new BadRequestException(
          'Poți oferi la schimb doar cărți din biblioteca ta',
        );
      }
      if (!book.availableForSwap) {
        throw new BadRequestException(
          'O carte din pachetul oferit nu este disponibilă',
        );
      }
    }

    const created = await this.prisma.$transaction(async (tx) => {
      const request = await tx.exchangeRequest.create({
        data: {
          requesterId,
          ownerId: requestedBook.userId,
          requestedBookId: dto.requestedBookId,
          offeredBookId: dto.offeredBookId,
          offeredAmount: dto.offeredAmount,
          message: dto.message,
          expiresAt: new Date(Date.now() + OFFER_EXPIRY_DAYS * 86_400_000),
        },
      });
      if (additionalIds.length > 0) {
        await tx.exchangeBundleBook.createMany({
          data: additionalIds.map((userBookId) => ({
            exchangeRequestId: request.id,
            userBookId,
          })),
        });
      }
      return tx.exchangeRequest.findUniqueOrThrow({
        where: { id: request.id },
        include: INCLUDE_FULL,
      });
    });

    await this.notifySafe(
      requestedBook.userId,
      'EXCHANGE_REQUEST_RECEIVED',
      `${publicName(created.requester)} ți-a trimis o cerere de schimb pentru "${requestedBook.book.title}"`,
      { exchangeRequestId: created.id },
    );

    // Semnal puternic de interes pentru „Cele mai căutate" - fire-and-forget,
    // un punct pierdut nu justifică să pice cererea de schimb.
    this.listingScore
      .recordExchangeRequest(dto.requestedBookId, requesterId)
      .catch(() => {});

    // Cererea devine vizibilă și acționabilă direct în chat, nu doar o
    // notificare separată - la fel ca oferta de preț (offers.service.ts).
    const conversation = await this.conversations.findOrCreateConversation(
      requesterId,
      requestedBook.userId,
    );
    const content = offeredBook
      ? additionalIds.length > 0
        ? `Cerere de schimb: „${offeredBook.book.title}" + încă ${additionalIds.length} ${additionalIds.length === 1 ? 'carte' : 'cărți'} pentru „${requestedBook.book.title}"`
        : `Cerere de schimb: „${offeredBook.book.title}" pentru „${requestedBook.book.title}"`
      : `Cerere de schimb pentru „${requestedBook.book.title}"`;
    await this.conversations.createExchangeRequestMessage(
      conversation.id,
      requesterId,
      created.id,
      content,
    );

    return {
      ...this.sanitizeParties(created),
      conversationId: conversation.id,
    };
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

  private async expireStalePending(where: {
    requesterId?: string;
    ownerId?: string;
  }) {
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
   * Ceilalți solicitanți PENDING pentru aceeași carte sunt doar informați -
   * cererile lor rămân deschise, ca să se redeschidă natural dacă schimbul
   * acesta nu se finalizează (vezi performCancel/rejectSiblingRequests).
   */
  async accept(id: string, userId: string) {
    const request = await this.findRequestForAction(id);
    this.assertIsOwner(request, userId);
    this.assertStatus(request, 'PENDING');

    const updated = await this.prisma.$transaction(async (tx) => {
      // Atomic guards prevent two concurrent accept() calls (e.g. on two
      // different pending requests for the same book) from both succeeding.
      const requestClaim = await tx.exchangeRequest.updateMany({
        where: { id, status: 'PENDING' },
        data: { status: 'ACCEPTED', acceptedAt: new Date() },
      });
      if (requestClaim.count === 0) {
        throw new BadRequestException(
          'Această cerere nu mai este în așteptare',
        );
      }

      const bookClaim = await tx.userBook.updateMany({
        where: { id: request.requestedBookId, availableForSwap: true },
        data: { availableForSwap: false },
      });
      if (bookClaim.count === 0) {
        throw new BadRequestException(
          'Cartea cerută nu mai este disponibilă la schimb',
        );
      }

      if (request.offeredBookId) {
        const offeredClaim = await tx.userBook.updateMany({
          where: { id: request.offeredBookId, availableForSwap: true },
          data: { availableForSwap: false },
        });
        if (offeredClaim.count === 0) {
          throw new BadRequestException(
            'Cartea oferită nu mai este disponibilă la schimb',
          );
        }
      }

      const bundleBookIds = await this.getBundleBookIds(id, tx);
      if (bundleBookIds.length > 0) {
        const bundleClaim = await tx.userBook.updateMany({
          where: { id: { in: bundleBookIds }, availableForSwap: true },
          data: { availableForSwap: false },
        });
        if (bundleClaim.count !== bundleBookIds.length) {
          throw new BadRequestException(
            'O carte din pachetul oferit nu mai este disponibilă la schimb',
          );
        }
      }

      return tx.exchangeRequest.findUniqueOrThrow({
        where: { id },
        include: INCLUDE_FULL,
      });
    });

    await this.broadcastStatusToConversation(id, 'ACCEPTED');
    await this.notifySafe(
      request.requesterId,
      'EXCHANGE_REQUEST_ACCEPTED',
      `${publicName(updated.owner)} a acceptat cererea ta de schimb pentru "${updated.requestedBook.book.title}"`,
      { exchangeRequestId: id },
    );
    await this.notifyOtherPendingRequesters(
      request.requestedBookId,
      id,
      'EXCHANGE_BOOK_PENDING',
      `"${updated.requestedBook.book.title}" este acum într-un schimb în desfășurare cu altcineva`,
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

    await this.broadcastStatusToConversation(id, 'REJECTED');
    await this.notifySafe(
      request.requesterId,
      'EXCHANGE_REQUEST_REJECTED',
      `${publicName(updated.owner)} a refuzat cererea ta de schimb pentru "${updated.requestedBook.book.title}"`,
      { exchangeRequestId: id },
    );

    return this.sanitizeParties(updated);
  }

  /** Regăsește conversația unde a fost postată cererea, ca schimbarea de status să apară live pe cardul din chat. */
  private async broadcastStatusToConversation(
    exchangeRequestId: string,
    status: string,
  ) {
    const message = await this.prisma.message.findFirst({
      where: { exchangeRequestId },
      select: { conversationId: true },
    });
    if (message) {
      this.conversations.broadcastExchangeRequestUpdate(
        message.conversationId,
        exchangeRequestId,
        status,
      );
    }
  }

  /**
   * Retragere (PENDING, doar solicitantul) sau anulare a unui schimb "în
   * desfășurare" (ACCEPTED, oricare parte - necesită motiv, vezi formularul
   * "What happened?"). Anularea din ACCEPTED eliberează cărțile și redeschide
   * (informativ) cererile PENDING ale altor solicitanți pentru aceeași carte.
   */
  async cancel(id: string, userId: string, dto: CancelExchangeDto = {}) {
    const request = await this.findRequestForAction(id);

    if (request.status === 'PENDING') {
      this.assertIsRequester(request, userId);
      const updated = await this.prisma.exchangeRequest.update({
        where: { id },
        data: {
          status: 'CANCELLED',
          cancelReason: dto.reason,
          cancelDetails: dto.details,
          cancelledBy: userId,
        },
        include: INCLUDE_FULL,
      });
      await this.broadcastStatusToConversation(id, 'CANCELLED');
      return this.sanitizeParties(updated);
    }

    if (request.status === 'ACCEPTED') {
      if (request.requesterId !== userId && request.ownerId !== userId) {
        throw new ForbiddenException('Nu ești parte în acest schimb');
      }
      if (!dto.reason) {
        throw new BadRequestException(
          'Trebuie să alegi un motiv pentru anulare',
        );
      }
      return this.performCancel(id, request, dto.reason, dto.details, userId);
    }

    throw new BadRequestException(
      `Acțiunea nu este permisă - cererea are statusul "${request.status}"`,
    );
  }

  /** Corpul comun al anulării unui schimb ACCEPTED - folosit atât de cancel() cât și de cron-ul de timeout. */
  private async performCancel(
    id: string,
    request: {
      requesterId: string;
      ownerId: string;
      requestedBookId: string;
      offeredBookId: string | null;
    },
    reason: string,
    details: string | undefined,
    cancelledBy: string,
  ) {
    const updated = await this.prisma.$transaction(async (tx) => {
      const claim = await tx.exchangeRequest.updateMany({
        where: { id, status: 'ACCEPTED' },
        data: {
          status: 'CANCELLED',
          cancelReason: reason,
          cancelDetails: details,
          cancelledBy,
        },
      });
      if (claim.count === 0) {
        throw new BadRequestException(
          'Acest schimb nu mai este în desfășurare',
        );
      }

      await tx.userBook.updateMany({
        where: { id: request.requestedBookId },
        data: { availableForSwap: true },
      });
      if (request.offeredBookId) {
        await tx.userBook.updateMany({
          where: { id: request.offeredBookId },
          data: { availableForSwap: true },
        });
      }
      const bundleBookIds = await this.getBundleBookIds(id, tx);
      if (bundleBookIds.length > 0) {
        await tx.userBook.updateMany({
          where: { id: { in: bundleBookIds } },
          data: { availableForSwap: true },
        });
      }

      return tx.exchangeRequest.findUniqueOrThrow({
        where: { id },
        include: INCLUDE_FULL,
      });
    });

    await this.broadcastStatusToConversation(id, 'CANCELLED');

    const reasonMessage =
      CANCEL_REASON_MESSAGES[reason] ?? details ?? 'motiv nespecificat';
    if (cancelledBy === 'system') {
      const timeoutMessage = `Schimbul pentru "${updated.requestedBook.book.title}" a expirat automat (${reasonMessage})`;
      await this.notifySafe(
        request.requesterId,
        'EXCHANGE_CANCELLED',
        timeoutMessage,
        {
          exchangeRequestId: id,
        },
      );
      await this.notifySafe(
        request.ownerId,
        'EXCHANGE_CANCELLED',
        timeoutMessage,
        {
          exchangeRequestId: id,
        },
      );
    } else {
      const otherUserId =
        cancelledBy === request.requesterId
          ? request.ownerId
          : request.requesterId;
      await this.notifySafe(
        otherUserId,
        'EXCHANGE_CANCELLED',
        `Schimbul pentru "${updated.requestedBook.book.title}" a fost anulat: ${reasonMessage}`,
        { exchangeRequestId: id },
      );
    }

    await this.notifyOtherPendingRequesters(
      request.requestedBookId,
      id,
      'EXCHANGE_REOPENED',
      `"${updated.requestedBook.book.title}" e din nou disponibilă la schimb (${reasonMessage})`,
    );

    return this.sanitizeParties(updated);
  }

  /** Informează solicitanții PENDING ai aceleiași cărți, fără să le atingă cererea. */
  private async notifyOtherPendingRequesters(
    bookId: string,
    excludeId: string,
    type: NotificationType,
    message: string,
  ) {
    const siblings = await this.prisma.exchangeRequest.findMany({
      where: {
        requestedBookId: bookId,
        status: 'PENDING',
        id: { not: excludeId },
      },
      select: { id: true, requesterId: true },
    });
    for (const sibling of siblings) {
      await this.notifySafe(sibling.requesterId, type, message, {
        exchangeRequestId: sibling.id,
      });
    }
  }

  /** La finalizarea schimbului, cererile PENDING rămase pentru aceeași carte nu mai au sens - se refuză. */
  private async rejectSiblingRequests(
    bookId: string,
    excludeId: string,
    message: string,
  ) {
    const siblings = await this.prisma.exchangeRequest.findMany({
      where: {
        requestedBookId: bookId,
        status: 'PENDING',
        id: { not: excludeId },
      },
      select: { id: true, requesterId: true },
    });
    if (siblings.length === 0) return;
    await this.prisma.exchangeRequest.updateMany({
      where: { id: { in: siblings.map((s) => s.id) } },
      data: {
        status: 'REJECTED',
        cancelReason: 'book_mismatch',
        cancelDetails: message,
      },
    });
    for (const sibling of siblings) {
      await this.notifySafe(
        sibling.requesterId,
        'EXCHANGE_REQUEST_REJECTED',
        message,
        {
          exchangeRequestId: sibling.id,
        },
      );
    }
  }

  /**
   * Oricare parte marchează schimbul ca finalizat din partea ei. Doar când
   * ambele au apăsat Done schimbul devine efectiv COMPLETED (cărțile trec
   * definitiv, XP-ul se acordă) - altfel celălalt e doar notificat să
   * confirme sau să conteste (vezi disputeDone).
   */
  async markDone(id: string, userId: string, dto: DoneExchangeDto) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');
    const isRequester = userId === request.requesterId;

    let updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: isRequester
        ? { requesterDoneAt: new Date(), requesterReviewForOwner: dto.comment }
        : { ownerDoneAt: new Date(), ownerReviewForRequester: dto.comment },
      include: INCLUDE_FULL,
    });

    if (updated.requesterDoneAt && updated.ownerDoneAt) {
      updated = await this.prisma.$transaction(async (tx) => {
        await tx.user.update({
          where: { id: updated.requesterId },
          data: {
            booksExchangedCount: { increment: 1 },
            booksReceivedCount: { increment: 1 },
            xp: { increment: XP_EXCHANGE_COMPLETED },
          },
        });
        await tx.user.update({
          where: { id: updated.ownerId },
          data: {
            booksExchangedCount: { increment: 1 },
            booksSharedCount: { increment: 1 },
            xp: { increment: XP_EXCHANGE_COMPLETED },
          },
        });

        await tx.userBook.update({
          where: { id: updated.requestedBookId },
          data: { permanentlyTransferred: true, availableForSwap: false },
        });
        if (updated.offeredBookId) {
          await tx.userBook.update({
            where: { id: updated.offeredBookId },
            data: { permanentlyTransferred: true, availableForSwap: false },
          });
        }
        const bundleBookIds = await this.getBundleBookIds(id, tx);
        if (bundleBookIds.length > 0) {
          await tx.userBook.updateMany({
            where: { id: { in: bundleBookIds } },
            data: { permanentlyTransferred: true, availableForSwap: false },
          });
        }

        return tx.exchangeRequest.update({
          where: { id },
          data: { status: 'COMPLETED' },
          include: INCLUDE_FULL,
        });
      });

      await this.broadcastStatusToConversation(id, 'COMPLETED');
      const doneMessage = `Schimbul pentru "${updated.requestedBook.book.title}" a fost finalizat`;
      await this.notifySafe(
        updated.requesterId,
        'EXCHANGE_COMPLETED',
        doneMessage,
        {
          exchangeRequestId: id,
        },
      );
      await this.notifySafe(
        updated.ownerId,
        'EXCHANGE_COMPLETED',
        doneMessage,
        {
          exchangeRequestId: id,
        },
      );
      await this.rejectSiblingRequests(
        updated.requestedBookId,
        id,
        `"${updated.requestedBook.book.title}" a fost deja dat altcuiva`,
      );
    } else {
      const otherUserId = isRequester ? updated.ownerId : updated.requesterId;
      const actorName = publicName(
        isRequester ? updated.requester : updated.owner,
      );
      await this.notifySafe(
        otherUserId,
        'EXCHANGE_DONE_PENDING_CONFIRMATION',
        `${actorName} a marcat schimbul pentru "${updated.requestedBook.book.title}" ca finalizat - confirmă și tu`,
        { exchangeRequestId: id },
      );
    }

    return this.sanitizeParties(updated);
  }

  /** Cealaltă parte nu e de acord că schimbul s-a încheiat - anulează Done-ul primit, fără să anuleze tot schimbul. */
  async disputeDone(id: string, userId: string) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');
    const isRequester = userId === request.requesterId;
    const otherAlreadyDone = isRequester
      ? request.ownerDoneAt
      : request.requesterDoneAt;
    if (!otherAlreadyDone) {
      throw new BadRequestException(
        'Cealaltă parte nu a marcat schimbul ca finalizat',
      );
    }

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: isRequester ? { ownerDoneAt: null } : { requesterDoneAt: null },
      include: INCLUDE_FULL,
    });

    const otherUserId = isRequester ? updated.ownerId : updated.requesterId;
    const actorName = publicName(
      isRequester ? updated.requester : updated.owner,
    );
    await this.notifySafe(
      otherUserId,
      'EXCHANGE_DONE_DISPUTED',
      `${actorName} nu a confirmat finalizarea schimbului pentru "${updated.requestedBook.book.title}"`,
      { exchangeRequestId: id },
    );

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
   * Oricare dintre cei doi participanți poate propune/reprograma
   * întâlnirea, cât timp schimbul e ACCEPTED. Necesită confirmarea
   * celeilalte părți (acceptMeeting) înainte de a debloca restul flow-ului.
   */
  async proposeMeeting(id: string, userId: string, dto: SetMeetingDto) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: {
        meetingTime: new Date(dto.meetingTime),
        meetingLocation: dto.meetingLocation,
        meetingProposedBy: userId,
        meetingAcceptedAt: null,
      },
      include: INCLUDE_FULL,
    });

    const isRequester = userId === updated.requesterId;
    const otherUserId = isRequester ? updated.ownerId : updated.requesterId;
    const actorName = publicName(
      isRequester ? updated.requester : updated.owner,
    );
    await this.notifySafe(
      otherUserId,
      'EXCHANGE_MEETING_PROPOSED',
      `${actorName} a propus o întâlnire pentru "${updated.requestedBook.book.title}" - confirmă sau propune altă oră`,
      { exchangeRequestId: updated.id },
    );

    return this.sanitizeParties(updated);
  }

  async acceptMeeting(id: string, userId: string) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');
    if (!request.meetingTime || !request.meetingProposedBy) {
      throw new BadRequestException('Nu există nicio întâlnire propusă');
    }
    if (request.meetingProposedBy === userId) {
      throw new BadRequestException(
        'Așteaptă răspunsul celeilalte părți la propunerea ta',
      );
    }

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: { meetingAcceptedAt: new Date() },
      include: INCLUDE_FULL,
    });

    await this.notifySafe(
      request.meetingProposedBy,
      'EXCHANGE_MEETING_ACCEPTED',
      `Întâlnirea pentru "${updated.requestedBook.book.title}" a fost confirmată`,
      { exchangeRequestId: id },
    );

    return this.sanitizeParties(updated);
  }

  async declineMeeting(id: string, userId: string) {
    return this.resetMeeting(
      id,
      userId,
      'EXCHANGE_MEETING_DECLINED',
      (name, title) =>
        `${name ?? 'Cineva'} a refuzat ora propusă pentru "${title}" - propune o oră nouă`,
    );
  }

  /** Postpone (pagina Ready to exchange) - identic tehnic cu declineMeeting, dar declanșat mai târziu în flow. */
  async postpone(id: string, userId: string) {
    return this.resetMeeting(
      id,
      userId,
      'EXCHANGE_POSTPONED',
      (name, title) =>
        `${name ?? 'Cineva'} a amânat schimbul pentru "${title}" - propuneți o nouă întâlnire`,
    );
  }

  private async resetMeeting(
    id: string,
    userId: string,
    type: NotificationType,
    messageFor: (actorName: string | null, bookTitle: string) => string,
  ) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');
    if (!request.meetingTime) {
      throw new BadRequestException('Nu există nicio întâlnire programată');
    }

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: {
        meetingTime: null,
        meetingLocation: null,
        meetingProposedBy: null,
        meetingAcceptedAt: null,
      },
      include: INCLUDE_FULL,
    });

    const isRequester = userId === updated.requesterId;
    const otherUserId = isRequester ? updated.ownerId : updated.requesterId;
    const actorName = publicName(
      isRequester ? updated.requester : updated.owner,
    );
    await this.notifySafe(
      otherUserId,
      type,
      messageFor(actorName, updated.requestedBook.book.title),
      { exchangeRequestId: id },
    );

    return this.sanitizeParties(updated);
  }

  /** Formularul de contact (nume/telefon opțional) - telefonul rămâne opțional, fallback-ul e mereu chatul din aplicație. */
  async shareContact(id: string, userId: string, dto: ShareContactDto) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');
    const isRequester = userId === request.requesterId;

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: isRequester
        ? {
            requesterContactPhone: dto.phone ?? null,
            requesterContactSharedAt: new Date(),
          }
        : {
            ownerContactPhone: dto.phone ?? null,
            ownerContactSharedAt: new Date(),
          },
      include: INCLUDE_FULL,
    });

    const otherUserId = isRequester ? updated.ownerId : updated.requesterId;
    const actorName = publicName(
      isRequester ? updated.requester : updated.owner,
    );
    await this.notifySafe(
      otherUserId,
      'EXCHANGE_CONTACT_SHARED',
      `${actorName} ți-a trimis detaliile de contact pentru schimb`,
      { exchangeRequestId: id },
    );

    return this.sanitizeParties(updated);
  }

  /** Checkbox-ul obligatoriu "I've read this" de pe safety recommendations - trebuie bifat de ambele părți. */
  async acknowledgeSafety(id: string, userId: string) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');
    const isRequester = userId === request.requesterId;

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: isRequester
        ? { requesterSafetyAckAt: new Date() }
        : { ownerSafetyAckAt: new Date() },
      include: INCLUDE_FULL,
    });

    if (updated.requesterSafetyAckAt && updated.ownerSafetyAckAt) {
      const message = `Sunteți gata de schimb pentru "${updated.requestedBook.book.title}"`;
      await this.notifySafe(updated.requesterId, 'EXCHANGE_READY', message, {
        exchangeRequestId: id,
      });
      await this.notifySafe(updated.ownerId, 'EXCHANGE_READY', message, {
        exchangeRequestId: id,
      });
    }

    return this.sanitizeParties(updated);
  }

  /**
   * "Condition Photos" (feature backlog #14) - fiecare parte urcă poze cu
   * starea cărții înainte de predare. Gate pe ACCEPTED, ca la safety-ack/
   * contact - nu are sens după ce schimbul e deja finalizat sau anulat.
   */
  async addConditionPhoto(id: string, userId: string, fileBuffer: Buffer) {
    const request = await this.findOwnedRequest(id, userId);
    this.assertStatus(request, 'ACCEPTED');
    const isRequester = userId === request.requesterId;
    const existing = isRequester
      ? request.requesterConditionPhotos
      : request.ownerConditionPhotos;

    if (existing.length >= MAX_CONDITION_PHOTOS) {
      throw new BadRequestException(
        `Poți adăuga maximum ${MAX_CONDITION_PHOTOS} poze`,
      );
    }

    const path = await this.storage.uploadImage(fileBuffer, 'exchange-condition');

    const updated = await this.prisma.exchangeRequest.update({
      where: { id },
      data: isRequester
        ? { requesterConditionPhotos: { push: path } }
        : { ownerConditionPhotos: { push: path } },
      include: INCLUDE_FULL,
    });

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
      request.offeredAmount != null
        ? ` (la prețul de ${request.offeredAmount.toString()} lei)`
        : '';

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
      .map(
        (r) =>
          r.requesterCommunicationForOwner ?? r.ownerCommunicationForRequester,
      )
      .filter((v): v is number => v !== null);
    const punctualityValues = ratedExchanges
      .map(
        (r) => r.requesterPunctualityForOwner ?? r.ownerPunctualityForRequester,
      )
      .filter((v): v is number => v !== null);
    const conditionValues = ratedExchanges
      .map((r) => r.requesterConditionForOwner ?? r.ownerConditionForRequester)
      .filter((v): v is number => v !== null);

    const average = (nums: number[]) =>
      nums.length === 0
        ? 0
        : Math.round((nums.reduce((a, b) => a + b, 0) / nums.length) * 10) / 10;

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

  /**
   * Timeout-ul de 7 zile (punctul 11 din flow): un schimb ACCEPTED care nu
   * ajunge la Done în 7 zile de la acceptare se anulează automat, cu același
   * mecanism ca un cancel manual (eliberare cărți + redeschidere informativă
   * a celorlalte cereri PENDING). Rulează orar, per rând cu try/catch - o
   * eroare pe un schimb nu blochează restul (același pattern ca
   * account-deletion.service.ts#purgeExpiredAccounts).
   */
  @Cron(CronExpression.EVERY_HOUR)
  async expireStaleAccepted(): Promise<void> {
    const cutoff = new Date(Date.now() - EXCHANGE_TIMEOUT_DAYS * 86_400_000);
    const stale = await this.prisma.exchangeRequest.findMany({
      where: { status: 'ACCEPTED', acceptedAt: { lt: cutoff } },
      select: { id: true },
    });
    if (stale.length === 0) {
      return;
    }

    this.logger.log(
      `Expir ${stale.length} schimburi ACCEPTED peste ${EXCHANGE_TIMEOUT_DAYS} zile`,
    );
    for (const { id } of stale) {
      try {
        const request = await this.prisma.exchangeRequest.findUnique({
          where: { id },
        });
        if (!request || request.status !== 'ACCEPTED') continue;
        await this.performCancel(id, request, 'expired', undefined, 'system');
      } catch (error) {
        this.logger.error(`Nu am putut expira schimbul ${id}`, error);
      }
    }
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
  private async expireIfStale<
    T extends { id: string; status: string; expiresAt: Date | null },
  >(request: T): Promise<T> {
    if (
      request.status !== 'PENDING' ||
      !request.expiresAt ||
      request.expiresAt > new Date()
    ) {
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

  /** Id-urile cărților din pachetul suplimentar oferit (feature backlog #17), în afara `offeredBookId`. */
  private async getBundleBookIds(
    exchangeRequestId: string,
    tx: Prisma.TransactionClient | PrismaService = this.prisma,
  ): Promise<string[]> {
    const rows = await tx.exchangeBundleBook.findMany({
      where: { exchangeRequestId },
      select: { userBookId: true },
    });
    return rows.map((r) => r.userBookId);
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

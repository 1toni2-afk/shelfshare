import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import type { Conversation, Message } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SafetyService } from '../safety/safety.service';
import { MailService } from '../mail/mail.service';
import { PresenceService } from './presence.service';
import { SendMessageDto } from './dto/send-message.dto';
import { ReportConversationDto } from './dto/report-conversation.dto';

const PARTICIPANT_SELECT = {
  id: true,
  name: true,
  city: true,
  profileImage: true,
  lastSeenAt: true,
} as const;

/**
 * Statusul ofertei se citește mereu direct de aici, nu e cache-uit pe mesaj -
 * la fiecare fetch de mesaje, cardul din chat arată starea reală curentă
 * (Pending/Acceptată/Refuzată), fără să fie nevoie de un event de socket
 * separat pentru actualizări.
 */
const PRICE_OFFER_SELECT = {
  select: {
    id: true,
    amount: true,
    status: true,
    userBook: { select: { book: { select: { title: true, coverUrl: true } } } },
  },
} as const;

/** Doar cât să se poată reda citatul deasupra răspunsului, nu tot mesajul. */
const REPLY_TO_SELECT = {
  select: {
    id: true,
    senderId: true,
    content: true,
    photo: true,
    location: true,
  },
} as const;

const MESSAGE_INCLUDE = {
  priceOffer: PRICE_OFFER_SELECT,
  replyTo: REPLY_TO_SELECT,
} as const;

/** Câte mesaje intră în emailul de moderare, ca previzualizare. */
const REPORT_EXCERPT_MESSAGES = 20;

@Injectable()
export class ConversationsService {
  private readonly logger = new Logger(ConversationsService.name);

  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private notifications: NotificationsService,
    private safety: SafetyService,
    private mail: MailService,
    private presence: PresenceService,
  ) {}

  /**
   * Găsește conversația dintre 2 utilizatori sau o creează dacă nu există.
   * userA/userB sunt normalizate alfabetic ca să nu apară duplicate.
   */
  async findOrCreateConversation(userId: string, otherUserId: string) {
    if (userId === otherUserId) {
      throw new BadRequestException(
        'Nu poți începe o conversație cu tine însuți',
      );
    }
    await this.safety.assertNotBlocked(userId, otherUserId);

    const [userAId, userBId] = [userId, otherUserId].sort();

    const existing = await this.prisma.conversation.findUnique({
      where: { userAId_userBId: { userAId, userBId } },
      include: {
        userA: { select: PARTICIPANT_SELECT },
        userB: { select: PARTICIPANT_SELECT },
      },
    });

    const conversation =
      existing ??
      (await this.prisma.conversation.create({
        data: { userAId, userBId },
        include: {
          userA: { select: PARTICIPANT_SELECT },
          userB: { select: PARTICIPANT_SELECT },
        },
      }));

    // Deschiderea explicită a unui chat arhivat îl scoate din arhivă - altfel
    // ar rămâne ascuns din listă imediat după ce tocmai l-ai folosit.
    if (existing && this.archivedAtFor(existing, userId)) {
      await this.setArchived(existing.id, userId, false);
    }

    // Aceeași formă ca getMyConversations() - frontend-ul așteaptă
    // "otherUser", nu userA/userB brute.
    const otherUser =
      conversation.userAId === userId ? conversation.userB : conversation.userA;

    return {
      id: conversation.id,
      otherUser: this.withPresence(otherUser),
      lastMessage: null,
      updatedAt: conversation.updatedAt,
      unreadCount: 0,
      isArchived: false,
    };
  }

  /**
   * @param archived `false` = inbox-ul normal, `true` = doar chaturile arhivate.
   */
  async getMyConversations(userId: string, archived = false) {
    const conversations = await this.prisma.conversation.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      include: {
        userA: { select: PARTICIPANT_SELECT },
        userB: { select: PARTICIPANT_SELECT },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
        _count: {
          select: {
            messages: { where: { senderId: { not: userId }, isRead: false } },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return conversations
      .filter((conv) => {
        const isArchived = this.archivedAtFor(conv, userId) !== null;
        if (isArchived !== archived) return false;

        // „Șterge chatul" nu șterge rânduri, doar ascunde tot ce a fost înainte
        // de un moment. Dacă și cel mai nou mesaj e mai vechi decât acel moment,
        // pentru userul curent conversația e goală - nu are ce afișa în listă.
        // Reapare de la sine când celălalt scrie ceva nou.
        const clearedAt = this.clearedAtFor(conv, userId);
        if (!clearedAt) return true;
        const lastMessage = conv.messages[0];
        return lastMessage != null && lastMessage.createdAt > clearedAt;
      })
      .map((conv) => ({
        id: conv.id,
        otherUser: this.withPresence(
          conv.userAId === userId ? conv.userB : conv.userA,
        ),
        lastMessage: conv.messages[0]
          ? this.mapMessage(conv.messages[0])
          : null,
        updatedAt: conv.updatedAt,
        unreadCount: conv._count.messages,
        isArchived: archived,
      }));
  }

  /** Total necitite pe toate conversațiile - pentru badge-ul din bara de jos. */
  async getUnreadCount(userId: string) {
    const count = await this.prisma.message.count({
      where: {
        senderId: { not: userId },
        isRead: false,
        conversation: { OR: [{ userAId: userId }, { userBId: userId }] },
      },
    });
    return { unreadCount: count };
  }

  async getMessages(
    conversationId: string,
    userId: string,
    limit = 50,
    before?: string,
  ) {
    const conversation = await this.assertParticipant(conversationId, userId);
    const clearedAt = this.clearedAtFor(conversation, userId);

    const messages = await this.prisma.message.findMany({
      where: {
        conversationId,
        ...this.createdAtFilter(clearedAt, before),
      },
      include: MESSAGE_INCLUDE,
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return messages.reverse().map((message) => this.mapMessage(message));
  }

  /**
   * Căutare în conversația curentă. Rezultatele vin cele mai noi întâi, ca
   * lista din UI să pornească de la ce e mai probabil relevant.
   */
  async searchMessages(
    conversationId: string,
    userId: string,
    query: string,
    limit = 50,
  ) {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      throw new BadRequestException(
        'Caută după cel puțin 2 caractere',
      );
    }

    const conversation = await this.assertParticipant(conversationId, userId);
    const clearedAt = this.clearedAtFor(conversation, userId);

    const messages = await this.prisma.message.findMany({
      where: {
        conversationId,
        ...this.createdAtFilter(clearedAt),
        // Locația e text vizibil în bulă la fel ca `content`, deci intră și ea
        // în căutare - „unde ne vedem" se caută la fel de des ca un cuvânt.
        OR: [
          { content: { contains: trimmed, mode: 'insensitive' } },
          { location: { contains: trimmed, mode: 'insensitive' } },
        ],
      },
      include: MESSAGE_INCLUDE,
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return messages.map((message) => this.mapMessage(message));
  }

  async sendMessage(senderId: string, dto: SendMessageDto) {
    if (!dto.content && !dto.location) {
      throw new BadRequestException('Mesajul trebuie să aibă text sau locație');
    }

    const conversation = await this.assertParticipant(
      dto.conversationId,
      senderId,
    );
    await this.assertNotBlockedInConversation(conversation, senderId);
    await this.assertReplyTarget(dto.conversationId, dto.replyToId);

    const [created] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId: dto.conversationId,
          senderId,
          content: dto.content,
          location: dto.location,
          locationLat: dto.locationLat,
          locationLng: dto.locationLng,
          meetingAt: dto.meetingAt ? new Date(dto.meetingAt) : undefined,
          replyToId: dto.replyToId,
        },
        include: MESSAGE_INCLUDE,
      }),
      this.prisma.conversation.update({
        where: { id: dto.conversationId },
        data: { updatedAt: new Date() },
      }),
    ]);

    await this.notifyNewMessage(conversation, senderId, dto.conversationId);

    return this.mapMessage(created);
  }

  /**
   * Mesaj special generat automat când cineva face o ofertă de preț (vezi
   * offers.service.ts#createOffer) - nu trece prin sendMessage() ca să nu
   * declanșeze și notificarea generică "mesaj nou" (oferta are deja
   * propria notificare, mai informativă, trimisă separat de OffersService).
   */
  async createPriceOfferMessage(
    conversationId: string,
    senderId: string,
    priceOfferId: string,
    content: string,
  ) {
    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: { conversationId, senderId, content, priceOfferId },
      }),
      this.prisma.conversation.update({
        where: { id: conversationId },
        data: { updatedAt: new Date() },
      }),
    ]);
    return message;
  }

  async sendPhotoMessage(
    senderId: string,
    conversationId: string,
    fileBuffer: Buffer,
    replyToId?: string,
  ) {
    const conversation = await this.assertParticipant(conversationId, senderId);
    await this.assertNotBlockedInConversation(conversation, senderId);
    await this.assertReplyTarget(conversationId, replyToId);

    const path = await this.storage.uploadImage(fileBuffer, 'chat');

    const [created] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: { conversationId, senderId, photo: path, replyToId },
        include: MESSAGE_INCLUDE,
      }),
      this.prisma.conversation.update({
        where: { id: conversationId },
        data: { updatedAt: new Date() },
      }),
    ]);

    await this.notifyNewMessage(conversation, senderId, conversationId);

    return this.mapMessage(created);
  }

  private async notifyNewMessage(
    conversation: { userAId: string; userBId: string },
    senderId: string,
    conversationId: string,
  ) {
    const recipientId =
      conversation.userAId === senderId
        ? conversation.userBId
        : conversation.userAId;

    // Mesajul deja s-a salvat cât timp ajungem aici - o eroare la
    // notificare nu trebuie să facă send-ul să pară eșuat pentru client.
    try {
      const sender = await this.prisma.user.findUnique({
        where: { id: senderId },
        select: { name: true },
      });
      const senderName = sender?.name?.trim() || 'Cineva';
      // Dedup pe conversationId: dacă expeditorul trimite mai multe mesaje
      // consecutive înainte ca destinatarul să deschidă conversația, actualizăm
      // aceeași notificare necitită în loc să creăm una nouă per mesaj.
      await this.notifications.upsertUnread(
        recipientId,
        'NEW_MESSAGE',
        `${senderName} ți-a trimis un mesaj`,
        { conversationId },
        'conversationId',
      );
    } catch (error) {
      this.logger.warn(
        `Nu am putut notifica mesajul nou către ${recipientId}: ${error}`,
      );
    }
  }

  async markAsRead(conversationId: string, userId: string) {
    await this.assertParticipant(conversationId, userId);

    const { count } = await this.prisma.message.updateMany({
      where: { conversationId, senderId: { not: userId }, isRead: false },
      data: { isRead: true },
    });

    // Deschiderea conversației îi rezolvă și notificarea de „mesaj nou"
    // aferentă din clopoțel - altfel ar rămâne necitită acolo la nesfârșit.
    await this.notifications.markAsReadByDataField(
      userId,
      'NEW_MESSAGE',
      'conversationId',
      conversationId,
    );

    return { message: 'Marcat ca citit', markedCount: count };
  }

  /**
   * „Șterge chatul": ascunde pentru userul curent tot ce s-a scris până acum,
   * fără să atingă istoricul celuilalt participant. Vezi comentariul din
   * schema.prisma pentru de ce nu ștergem rândurile.
   */
  async clearConversation(conversationId: string, userId: string) {
    const conversation = await this.assertParticipant(conversationId, userId);
    const side = this.sideOf(conversation, userId);

    await this.prisma.$transaction([
      this.prisma.conversation.update({
        where: { id: conversationId },
        data:
          side === 'A'
            ? { userAClearedAt: new Date(), userAArchivedAt: null }
            : { userBClearedAt: new Date(), userBArchivedAt: null },
      }),
      // Mesajele șterse nu mai pot fi citite de el, deci nici nu mai au ce
      // căuta în badge-ul de necitite.
      this.prisma.message.updateMany({
        where: { conversationId, senderId: { not: userId }, isRead: false },
        data: { isRead: true },
      }),
    ]);

    return { message: 'Conversația a fost ștearsă' };
  }

  async setArchived(conversationId: string, userId: string, archived: boolean) {
    const conversation = await this.assertParticipant(conversationId, userId);
    const side = this.sideOf(conversation, userId);
    const value = archived ? new Date() : null;

    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: side === 'A' ? { userAArchivedAt: value } : { userBArchivedAt: value },
    });

    return {
      message: archived ? 'Conversație arhivată' : 'Conversație dezarhivată',
      isArchived: archived,
    };
  }

  /**
   * Raportarea unei conversații: pe lângă rândul din `reports`, exportăm
   * transcriptul integral ca fișier text în storage și trimitem un email de
   * moderare cu linkul. Exportul e un snapshot - dacă cei doi își șterg apoi
   * chatul, dovada rămâne.
   */
  async reportConversation(
    conversationId: string,
    reporterId: string,
    dto: ReportConversationDto,
  ) {
    const conversation = await this.assertParticipant(
      conversationId,
      reporterId,
    );
    const reportedUserId =
      conversation.userAId === reporterId
        ? conversation.userBId
        : conversation.userAId;

    const [reporter, reported, messages] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: reporterId },
        select: { id: true, name: true, email: true },
      }),
      this.prisma.user.findUnique({
        where: { id: reportedUserId },
        select: { id: true, name: true, email: true },
      }),
      // Transcriptul e integral și în ordine cronologică, indiferent ce a
      // șters fiecare pentru sine - moderarea are nevoie de tot contextul.
      this.prisma.message.findMany({
        where: { conversationId },
        orderBy: { createdAt: 'asc' },
      }),
    ]);

    const describe = (user: { id: string; name: string | null; email: string }) =>
      `${user.name ?? 'fără nume'} <${user.email}> [${user.id}]`;

    const lines = messages.map((message) =>
      this.formatTranscriptLine(message, reporterId, reportedUserId),
    );

    const transcript = [
      '=== TRANSCRIPT CONVERSAȚIE RAPORTATĂ - SHELFSHARE ===',
      `Conversație: ${conversationId}`,
      `Reclamant:   ${reporter ? describe(reporter) : reporterId}`,
      `Reclamat:    ${reported ? describe(reported) : reportedUserId}`,
      `Motiv:       ${dto.reason}`,
      `Detalii:     ${dto.details ?? '-'}`,
      `Exportat:    ${new Date().toISOString()}`,
      `Mesaje:      ${messages.length}`,
      '',
      ...lines,
      '',
      '=== SFÂRȘIT TRANSCRIPT ===',
    ].join('\n');

    const transcriptPath = await this.storage.uploadTextFile(
      transcript,
      'chat-reports',
      `conversatie-${conversationId}`,
    );

    const report = await this.prisma.report.create({
      data: {
        reporterId,
        reportedUserId,
        reason: dto.reason,
        details: dto.details,
        conversationId,
        transcriptPath,
      },
    });

    // Raportul e deja salvat, cu tot cu transcript - dacă emailul cade,
    // userul nu trebuie să vadă o eroare și să raporteze din nou.
    try {
      await this.mail.sendChatReportNotification({
        reportId: report.id,
        reporter: reporter ? describe(reporter) : reporterId,
        reported: reported ? describe(reported) : reportedUserId,
        reason: dto.reason,
        details: dto.details,
        messageCount: messages.length,
        transcriptUrl: this.storage.getPublicUrl(transcriptPath),
        excerpt: lines.slice(-REPORT_EXCERPT_MESSAGES).join('\n') || '(niciun mesaj)',
      });
    } catch (error) {
      this.logger.error(
        `Raport ${report.id} salvat, dar emailul de moderare a eșuat: ${error}`,
      );
    }

    return { message: 'Conversația a fost raportată', reportId: report.id };
  }

  async getParticipants(conversationId: string): Promise<[string, string]> {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
    });
    if (!conversation) {
      throw new NotFoundException('Conversația nu a fost găsită');
    }
    return [conversation.userAId, conversation.userBId];
  }

  /** Cu cine vorbește userul - pentru a difuza prezența doar celor interesați. */
  async getChatPartnerIds(userId: string): Promise<string[]> {
    const conversations = await this.prisma.conversation.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      select: { userAId: true, userBId: true },
    });
    return conversations.map((conv) =>
      conv.userAId === userId ? conv.userBId : conv.userAId,
    );
  }

  private formatTranscriptLine(
    message: Message,
    reporterId: string,
    reportedUserId: string,
  ): string {
    const who =
      message.senderId === reporterId
        ? 'RECLAMANT'
        : message.senderId === reportedUserId
          ? 'RECLAMAT'
          : message.senderId;

    const parts: string[] = [];
    if (message.content) parts.push(message.content);
    if (message.photo) {
      parts.push(`[foto: ${this.storage.getPublicUrl(message.photo)}]`);
    }
    if (message.location) {
      const coords =
        message.locationLat != null && message.locationLng != null
          ? ` (${message.locationLat}, ${message.locationLng})`
          : '';
      parts.push(`[locație: ${message.location}${coords}]`);
    }
    if (message.meetingAt) {
      parts.push(`[întâlnire: ${message.meetingAt.toISOString()}]`);
    }
    if (message.priceOfferId) parts.push('[ofertă de preț]');

    return `[${message.createdAt.toISOString()}] ${who}: ${parts.join(' ') || '(gol)'}`;
  }

  /**
   * `photo` e stocat ca o cheie în bucket, nu ca URL - clientul nu are de unde
   * să știe baza publică, deci o rezolvăm aici, la fel ca la orice altă
   * imagine servită din storage.
   */
  private mapMessage<T extends { photo: string | null }>(message: T): T {
    const replyTo = (message as { replyTo?: { photo: string | null } | null })
      .replyTo;

    return {
      ...message,
      photo: message.photo ? this.storage.getPublicUrl(message.photo) : null,
      ...(replyTo
        ? {
            replyTo: {
              ...replyTo,
              photo: replyTo.photo
                ? this.storage.getPublicUrl(replyTo.photo)
                : null,
            },
          }
        : {}),
    };
  }

  private withPresence<T extends { id: string; lastSeenAt: Date | null }>(
    user: T,
  ) {
    return { ...user, isOnline: this.presence.isOnline(user.id) };
  }

  /**
   * Limita inferioară (chatul șters de mine) și cea superioară (paginare)
   * ajung amândouă pe `createdAt`, deci trebuie combinate într-un singur
   * filtru - două chei `createdAt` separate s-ar suprascrie una pe alta.
   */
  private createdAtFilter(clearedAt: Date | null, before?: string) {
    if (!clearedAt && !before) return {};
    return {
      createdAt: {
        ...(clearedAt ? { gt: clearedAt } : {}),
        ...(before ? { lt: new Date(before) } : {}),
      },
    };
  }

  private sideOf(
    conversation: Pick<Conversation, 'userAId'>,
    userId: string,
  ): 'A' | 'B' {
    return conversation.userAId === userId ? 'A' : 'B';
  }

  private clearedAtFor(
    conversation: Pick<
      Conversation,
      'userAId' | 'userAClearedAt' | 'userBClearedAt'
    >,
    userId: string,
  ): Date | null {
    return this.sideOf(conversation, userId) === 'A'
      ? conversation.userAClearedAt
      : conversation.userBClearedAt;
  }

  private archivedAtFor(
    conversation: Pick<
      Conversation,
      'userAId' | 'userAArchivedAt' | 'userBArchivedAt'
    >,
    userId: string,
  ): Date | null {
    return this.sideOf(conversation, userId) === 'A'
      ? conversation.userAArchivedAt
      : conversation.userBArchivedAt;
  }

  /** Nu se poate răspunde la un mesaj din altă conversație. */
  private async assertReplyTarget(conversationId: string, replyToId?: string) {
    if (!replyToId) return;
    const target = await this.prisma.message.findUnique({
      where: { id: replyToId },
      select: { conversationId: true },
    });
    if (!target || target.conversationId !== conversationId) {
      throw new BadRequestException(
        'Mesajul la care răspunzi nu există în această conversație',
      );
    }
  }

  private async assertNotBlockedInConversation(
    conversation: { userAId: string; userBId: string },
    senderId: string,
  ) {
    const recipientId =
      conversation.userAId === senderId
        ? conversation.userBId
        : conversation.userAId;
    await this.safety.assertNotBlocked(senderId, recipientId);
  }

  private async assertParticipant(conversationId: string, userId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
    });
    if (!conversation) {
      throw new NotFoundException('Conversația nu a fost găsită');
    }
    if (conversation.userAId !== userId && conversation.userBId !== userId) {
      throw new ForbiddenException('Nu faci parte din această conversație');
    }
    return conversation;
  }
}

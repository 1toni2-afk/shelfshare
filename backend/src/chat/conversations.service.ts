import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { SendMessageDto } from './dto/send-message.dto';

const PARTICIPANT_SELECT = {
  id: true,
  name: true,
  city: true,
  profileImage: true,
} as const;

@Injectable()
export class ConversationsService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
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

    const [userAId, userBId] = [userId, otherUserId].sort();

    const existing = await this.prisma.conversation.findUnique({
      where: { userAId_userBId: { userAId, userBId } },
      include: {
        userA: { select: PARTICIPANT_SELECT },
        userB: { select: PARTICIPANT_SELECT },
      },
    });
    if (existing) return existing;

    return this.prisma.conversation.create({
      data: { userAId, userBId },
      include: {
        userA: { select: PARTICIPANT_SELECT },
        userB: { select: PARTICIPANT_SELECT },
      },
    });
  }

  async getMyConversations(userId: string) {
    const conversations = await this.prisma.conversation.findMany({
      where: { OR: [{ userAId: userId }, { userBId: userId }] },
      include: {
        userA: { select: PARTICIPANT_SELECT },
        userB: { select: PARTICIPANT_SELECT },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return conversations.map((conv) => ({
      id: conv.id,
      otherUser: conv.userAId === userId ? conv.userB : conv.userA,
      lastMessage: conv.messages[0] ?? null,
      updatedAt: conv.updatedAt,
    }));
  }

  async getMessages(
    conversationId: string,
    userId: string,
    limit = 50,
    before?: string,
  ) {
    await this.assertParticipant(conversationId, userId);

    const messages = await this.prisma.message.findMany({
      where: {
        conversationId,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    return messages.reverse();
  }

  async sendMessage(senderId: string, dto: SendMessageDto) {
    if (!dto.content && !dto.location) {
      throw new BadRequestException('Mesajul trebuie să aibă text sau locație');
    }

    await this.assertParticipant(dto.conversationId, senderId);

    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: {
          conversationId: dto.conversationId,
          senderId,
          content: dto.content,
          location: dto.location,
        },
      }),
      this.prisma.conversation.update({
        where: { id: dto.conversationId },
        data: { updatedAt: new Date() },
      }),
    ]);

    return message;
  }

  async sendPhotoMessage(
    senderId: string,
    conversationId: string,
    fileBuffer: Buffer,
  ) {
    await this.assertParticipant(conversationId, senderId);

    const path = await this.storage.uploadImage(fileBuffer, 'chat');

    const [message] = await this.prisma.$transaction([
      this.prisma.message.create({
        data: { conversationId, senderId, photo: path },
      }),
      this.prisma.conversation.update({
        where: { id: conversationId },
        data: { updatedAt: new Date() },
      }),
    ]);

    return { ...message, photoUrl: this.storage.getPublicUrl(path) };
  }

  async markAsRead(conversationId: string, userId: string) {
    await this.assertParticipant(conversationId, userId);

    await this.prisma.message.updateMany({
      where: { conversationId, senderId: { not: userId }, isRead: false },
      data: { isRead: true },
    });

    return { message: 'Marcat ca citit' };
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

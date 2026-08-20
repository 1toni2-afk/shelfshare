import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const PARTICIPANT_SELECT = {
  id: true,
  name: true,
  email: true,
  profileImage: true,
} as const;

/**
 * „Chat with an admin" - vezi comentariul de pe AdminSupportConversation în
 * schema.prisma. Spre deosebire de ConversationsService (chat 1:1 obișnuit),
 * aici nu există un „celălalt participant" fix: userul obișnuit are o
 * singură conversație cu ECHIPA de admini, iar orice admin poate citi și
 * răspunde la orice conversație - lista de admini (`User.isAdmin`) e
 * verificată la nivel de guard (AdminGuard), nu aici.
 */
@Injectable()
export class AdminChatService {
  constructor(private prisma: PrismaService) {}

  /** Conversația userului curent cu echipa de admini - creată la prima deschidere. */
  private async getOrCreateMyConversation(userId: string) {
    return this.prisma.adminSupportConversation.upsert({
      where: { userId },
      create: { userId },
      update: {},
    });
  }

  async getMyConversation(userId: string) {
    const conversation = await this.getOrCreateMyConversation(userId);
    const messages = await this.prisma.adminSupportMessage.findMany({
      where: { conversationId: conversation.id },
      orderBy: { createdAt: 'asc' },
    });
    return { id: conversation.id, messages };
  }

  async sendMyMessage(userId: string, content: string) {
    const conversation = await this.getOrCreateMyConversation(userId);
    const [message] = await this.prisma.$transaction([
      this.prisma.adminSupportMessage.create({
        data: {
          conversationId: conversation.id,
          senderId: userId,
          content,
          isFromAdmin: false,
        },
      }),
      this.prisma.adminSupportConversation.update({
        where: { id: conversation.id },
        data: { lastMessageAt: new Date(), userLastReadAt: new Date() },
      }),
    ]);
    return message;
  }

  async markMyConversationRead(userId: string) {
    const conversation = await this.getOrCreateMyConversation(userId);
    await this.prisma.adminSupportConversation.update({
      where: { id: conversation.id },
      data: { userLastReadAt: new Date() },
    });
    return { message: 'Marcat ca citit' };
  }

  // -------------------------------------------------------------------------
  // Latura de admin - orice admin vede și poate răspunde la orice conversație.
  // -------------------------------------------------------------------------

  /** Toate conversațiile de suport, cele mai recent active primele. */
  async getAllConversations() {
    const conversations = await this.prisma.adminSupportConversation.findMany({
      where: { messages: { some: {} } },
      include: {
        user: { select: PARTICIPANT_SELECT },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      orderBy: [{ lastMessageAt: 'desc' }, { createdAt: 'desc' }],
    });

    return conversations.map((conv) => ({
      id: conv.id,
      user: conv.user,
      lastMessage: conv.messages[0] ?? null,
      lastMessageAt: conv.lastMessageAt,
      // „Necitit de admini" = ultimul mesaj a venit de la user DUPĂ ce vreun
      // admin a marcat-o ca citită ultima oară (sau n-a fost citită niciodată).
      hasUnread:
        conv.messages[0] != null &&
        !conv.messages[0].isFromAdmin &&
        (conv.adminLastReadAt == null ||
          conv.messages[0].createdAt > conv.adminLastReadAt),
    }));
  }

  async getConversationMessages(conversationId: string) {
    const conversation = await this.prisma.adminSupportConversation.findUnique({
      where: { id: conversationId },
      include: { user: { select: PARTICIPANT_SELECT } },
    });
    if (!conversation) {
      throw new NotFoundException('Conversația nu a fost găsită');
    }
    const messages = await this.prisma.adminSupportMessage.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'asc' },
    });
    return { id: conversation.id, user: conversation.user, messages };
  }

  async sendAdminReply(conversationId: string, adminId: string, content: string) {
    const conversation = await this.prisma.adminSupportConversation.findUnique({
      where: { id: conversationId },
    });
    if (!conversation) {
      throw new NotFoundException('Conversația nu a fost găsită');
    }

    const [message] = await this.prisma.$transaction([
      this.prisma.adminSupportMessage.create({
        data: {
          conversationId,
          senderId: adminId,
          content,
          isFromAdmin: true,
        },
      }),
      this.prisma.adminSupportConversation.update({
        where: { id: conversationId },
        data: { lastMessageAt: new Date(), adminLastReadAt: new Date() },
      }),
    ]);
    return message;
  }

  async markConversationReadByAdmin(conversationId: string) {
    const conversation = await this.prisma.adminSupportConversation.findUnique({
      where: { id: conversationId },
    });
    if (!conversation) {
      throw new NotFoundException('Conversația nu a fost găsită');
    }
    await this.prisma.adminSupportConversation.update({
      where: { id: conversationId },
      data: { adminLastReadAt: new Date() },
    });
    return { message: 'Marcat ca citit' };
  }
}

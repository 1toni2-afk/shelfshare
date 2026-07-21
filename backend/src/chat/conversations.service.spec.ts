import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SafetyService } from '../safety/safety.service';

describe('ConversationsService', () => {
  let service: ConversationsService;
  let prisma: {
    conversation: Record<string, jest.Mock>;
    message: Record<string, jest.Mock>;
    $transaction: jest.Mock;
  };
  let notifications: jest.Mocked<NotificationsService>;

  const userA = {
    id: 'user-a',
    name: 'Andrei',
    city: 'București',
    profileImage: null,
  };
  const userB = {
    id: 'user-b',
    name: 'Maria',
    city: 'Cluj-Napoca',
    profileImage: null,
  };

  beforeEach(async () => {
    prisma = {
      conversation: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      message: { create: jest.fn() },
      $transaction: jest.fn((ops: unknown[]) => Promise.all(ops)),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ConversationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: StorageService, useValue: {} },
        { provide: NotificationsService, useValue: { create: jest.fn() } },
        {
          provide: SafetyService,
          useValue: { assertNotBlocked: jest.fn() },
        },
      ],
    }).compile();

    service = module.get(ConversationsService);
    notifications = module.get(NotificationsService);
  });

  describe('findOrCreateConversation', () => {
    it('respinge o conversație cu tine însuți', async () => {
      await expect(
        service.findOrCreateConversation('user-a', 'user-a'),
      ).rejects.toThrow(BadRequestException);
    });

    it('returnează forma {id, otherUser, lastMessage, updatedAt}, nu userA/userB brute', async () => {
      prisma.conversation.findUnique.mockResolvedValue(null);
      prisma.conversation.create.mockResolvedValue({
        id: 'conv-1',
        userAId: 'user-a',
        userBId: 'user-b',
        userA,
        userB,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      });

      const result = await service.findOrCreateConversation('user-a', 'user-b');

      expect(result).toEqual({
        id: 'conv-1',
        otherUser: userB,
        lastMessage: null,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      });
    });

    it('identifică corect otherUser indiferent cine e userA/userB în DB', async () => {
      // user-b a apelat, dar in DB user-b e "userA" (normalizare alfabetică)
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-1',
        userAId: 'user-b',
        userBId: 'user-a',
        userA: userB,
        userB: userA,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      });

      const result = await service.findOrCreateConversation('user-a', 'user-b');

      expect(result.otherUser).toEqual(userB);
    });

    it('nu creează o conversație nouă dacă una există deja', async () => {
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-existing',
        userAId: 'user-a',
        userBId: 'user-b',
        userA,
        userB,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      });

      await service.findOrCreateConversation('user-a', 'user-b');

      expect(prisma.conversation.create).not.toHaveBeenCalled();
    });
  });

  describe('sendMessage', () => {
    const conversation = { id: 'conv-1', userAId: 'user-a', userBId: 'user-b' };

    beforeEach(() => {
      prisma.conversation.findUnique.mockResolvedValue(conversation);
      prisma.message.create.mockResolvedValue({
        id: 'msg-1',
        content: 'salut',
      });
      prisma.conversation.update.mockResolvedValue(conversation);
    });

    it('notifică celălalt participant, nu pe expeditor', async () => {
      await service.sendMessage('user-a', {
        conversationId: 'conv-1',
        content: 'salut',
      });

      expect(notifications.create).toHaveBeenCalledWith(
        'user-b',
        'NEW_MESSAGE',
        expect.any(String),
        { conversationId: 'conv-1' },
      );
    });

    it('nu eșuează dacă trimiterea notificării pică - mesajul deja s-a salvat', async () => {
      notifications.create.mockRejectedValue(new Error('notif service down'));

      const result = await service.sendMessage('user-a', {
        conversationId: 'conv-1',
        content: 'salut',
      });

      expect(result).toEqual({ id: 'msg-1', content: 'salut' });
    });
  });
});

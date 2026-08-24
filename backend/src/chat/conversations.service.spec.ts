import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { ConversationsService } from './conversations.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { NotificationsService } from '../notifications/notifications.service';
import { SafetyService } from '../safety/safety.service';
import { MailService } from '../mail/mail.service';
import { PresenceService } from './presence.service';
import { RealtimeService } from '../common/realtime/realtime.service';

describe('ConversationsService', () => {
  let service: ConversationsService;
  let prisma: {
    conversation: Record<string, jest.Mock>;
    message: Record<string, jest.Mock>;
    user: Record<string, jest.Mock>;
    report: Record<string, jest.Mock>;
    $transaction: jest.Mock;
  };
  let notifications: jest.Mocked<NotificationsService>;
  let storage: {
    uploadTextFile: jest.Mock;
    getPublicUrl: jest.Mock;
    getSignedUrl: jest.Mock;
  };
  let mail: { sendChatReportNotification: jest.Mock };
  let presence: { isOnline: jest.Mock };
  let realtime: { emitToConversation: jest.Mock; emitToUser: jest.Mock };

  const userA = {
    id: 'user-a',
    name: 'Andrei',
    city: 'București',
    profileImage: null,
    lastSeenAt: null,
  };
  const userB = {
    id: 'user-b',
    name: 'Maria',
    city: 'Cluj-Napoca',
    profileImage: null,
    lastSeenAt: null,
  };

  beforeEach(async () => {
    prisma = {
      conversation: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      message: {
        create: jest.fn(),
        findUnique: jest.fn(),
        findMany: jest.fn(),
        updateMany: jest.fn(),
        count: jest.fn(),
      },
      user: { findUnique: jest.fn() },
      report: { create: jest.fn() },
      $transaction: jest.fn((ops: unknown[]) => Promise.all(ops)),
    };
    storage = {
      uploadTextFile: jest.fn().mockResolvedValue('chat-reports/x.txt'),
      getPublicUrl: jest.fn((path: string) => `https://cdn.test/${path}`),
      // Transcripturile din `chat-reports` nu mai sunt citibile anonim - merg
      // prin URL semnat, cu expirare (vezi StorageService.getSignedUrl).
      getSignedUrl: jest
        .fn()
        .mockImplementation((path: string) =>
          Promise.resolve(`https://cdn.test/${path}?signature=test`),
        ),
    };
    mail = { sendChatReportNotification: jest.fn() };
    presence = { isOnline: jest.fn().mockReturnValue(false) };
    realtime = { emitToConversation: jest.fn(), emitToUser: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ConversationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: StorageService, useValue: storage },
        {
          provide: NotificationsService,
          useValue: {
            create: jest.fn(),
            upsertUnread: jest.fn(),
            markAsReadByDataField: jest.fn(),
          },
        },
        {
          provide: SafetyService,
          useValue: { assertNotBlocked: jest.fn() },
        },
        { provide: MailService, useValue: mail },
        { provide: PresenceService, useValue: presence },
        { provide: RealtimeService, useValue: realtime },
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
        otherUser: { ...userB, isOnline: false },
        lastMessage: null,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
        unreadCount: 0,
        isArchived: false,
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
        userAArchivedAt: null,
        userBArchivedAt: null,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      });

      const result = await service.findOrCreateConversation('user-a', 'user-b');

      expect(result.otherUser).toEqual({ ...userB, isOnline: false });
    });

    it('nu creează o conversație nouă dacă una există deja', async () => {
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-existing',
        userAId: 'user-a',
        userBId: 'user-b',
        userA,
        userB,
        userAArchivedAt: null,
        userBArchivedAt: null,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      });

      await service.findOrCreateConversation('user-a', 'user-b');

      expect(prisma.conversation.create).not.toHaveBeenCalled();
    });

    it('scoate din arhivă conversația pe care userul o redeschide', async () => {
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-1',
        userAId: 'user-a',
        userBId: 'user-b',
        userA,
        userB,
        userAArchivedAt: new Date('2026-01-02T00:00:00.000Z'),
        userBArchivedAt: null,
        updatedAt: new Date('2026-01-01T00:00:00.000Z'),
      });

      await service.findOrCreateConversation('user-a', 'user-b');

      expect(prisma.conversation.update).toHaveBeenCalledWith({
        where: { id: 'conv-1' },
        data: { userAArchivedAt: null },
      });
    });
  });

  describe('getMyConversations', () => {
    const base = {
      id: 'conv-1',
      userAId: 'user-a',
      userBId: 'user-b',
      userA,
      userB,
      userAArchivedAt: null,
      userBArchivedAt: null,
      userAClearedAt: null,
      userBClearedAt: null,
      messages: [],
      _count: { messages: 3 },
      updatedAt: new Date('2026-01-01T00:00:00.000Z'),
    };

    it('ascunde conversația ștearsă cât timp nu a mai venit niciun mesaj nou', async () => {
      prisma.conversation.findMany.mockResolvedValue([
        {
          ...base,
          userAClearedAt: new Date('2026-02-01T00:00:00.000Z'),
          messages: [
            {
              id: 'msg-old',
              photo: null,
              createdAt: new Date('2026-01-15T00:00:00.000Z'),
            },
          ],
        },
      ]);

      expect(await service.getMyConversations('user-a')).toEqual([]);
    });

    it('readuce conversația ștearsă în listă la primul mesaj mai nou', async () => {
      prisma.conversation.findMany.mockResolvedValue([
        {
          ...base,
          userAClearedAt: new Date('2026-02-01T00:00:00.000Z'),
          messages: [
            {
              id: 'msg-new',
              photo: null,
              createdAt: new Date('2026-03-01T00:00:00.000Z'),
            },
          ],
        },
      ]);

      const result = await service.getMyConversations('user-a');

      expect(result).toHaveLength(1);
      expect(result[0].unreadCount).toBe(3);
    });

    it('separă arhivate de neaarhivate pentru userul care a arhivat', async () => {
      prisma.conversation.findMany.mockResolvedValue([
        { ...base, userAArchivedAt: new Date('2026-02-01T00:00:00.000Z') },
      ]);

      // Pentru user-a e arhivată, pentru user-b nu.
      expect(await service.getMyConversations('user-a')).toHaveLength(0);
      expect(await service.getMyConversations('user-a', true)).toHaveLength(1);
      expect(await service.getMyConversations('user-b')).toHaveLength(1);
    });

    it('transformă calea pozei din storage în URL public', async () => {
      prisma.conversation.findMany.mockResolvedValue([
        {
          ...base,
          messages: [
            {
              id: 'msg-1',
              photo: 'chat/abc.webp',
              createdAt: new Date('2026-01-01T00:00:00.000Z'),
            },
          ],
        },
      ]);

      const result = await service.getMyConversations('user-a');

      expect(result[0].lastMessage?.photo).toBe(
        'https://cdn.test/chat/abc.webp',
      );
    });
  });

  describe('sendMessage', () => {
    const conversation = {
      id: 'conv-1',
      userAId: 'user-a',
      userBId: 'user-b',
      userAClearedAt: null,
      userBClearedAt: null,
    };

    beforeEach(() => {
      prisma.conversation.findUnique.mockResolvedValue(conversation);
      prisma.message.create.mockResolvedValue({
        id: 'msg-1',
        content: 'salut',
        photo: null,
      });
      prisma.conversation.update.mockResolvedValue(conversation);
      prisma.user.findUnique.mockResolvedValue({ name: 'Ana' });
    });

    it('notifică celălalt participant, nu pe expeditor', async () => {
      await service.sendMessage('user-a', {
        conversationId: 'conv-1',
        content: 'salut',
      });

      expect(notifications.upsertUnread).toHaveBeenCalledWith(
        'user-b',
        'NEW_MESSAGE',
        expect.any(String),
        { conversationId: 'conv-1' },
        'conversationId',
      );
    });

    it('nu eșuează dacă trimiterea notificării pică - mesajul deja s-a salvat', async () => {
      notifications.create.mockRejectedValue(new Error('notif service down'));

      const result = await service.sendMessage('user-a', {
        conversationId: 'conv-1',
        content: 'salut',
      });

      expect(result).toEqual({ id: 'msg-1', content: 'salut', photo: null });
    });

    it('respinge un reply către un mesaj din altă conversație', async () => {
      prisma.message.findUnique.mockResolvedValue({
        conversationId: 'alta-conv',
      });

      await expect(
        service.sendMessage('user-a', {
          conversationId: 'conv-1',
          content: 'salut',
          replyToId: 'msg-strain',
        }),
      ).rejects.toThrow(BadRequestException);
      expect(prisma.message.create).not.toHaveBeenCalled();
    });
  });

  describe('clearConversation', () => {
    it('setează clearedAt doar pe capătul userului curent', async () => {
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-1',
        userAId: 'user-a',
        userBId: 'user-b',
      });

      await service.clearConversation('conv-1', 'user-b');

      expect(prisma.conversation.update).toHaveBeenCalledWith({
        where: { id: 'conv-1' },
        data: {
          userBClearedAt: expect.any(Date),
          userBArchivedAt: null,
        },
      });
    });
  });

  describe('searchMessages', () => {
    it('cere cel puțin 2 caractere', async () => {
      await expect(
        service.searchMessages('conv-1', 'user-a', 'a'),
      ).rejects.toThrow(BadRequestException);
    });

    it('caută și în textul locației, nu doar în conținut', async () => {
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-1',
        userAId: 'user-a',
        userBId: 'user-b',
        userAClearedAt: null,
        userBClearedAt: null,
      });
      prisma.message.findMany.mockResolvedValue([]);

      await service.searchMessages('conv-1', 'user-a', 'cismigiu');

      const where = prisma.message.findMany.mock.calls[0][0].where;
      expect(where.OR).toEqual([
        { content: { contains: 'cismigiu', mode: 'insensitive' } },
        { location: { contains: 'cismigiu', mode: 'insensitive' } },
      ]);
    });
  });

  describe('reportConversation', () => {
    beforeEach(() => {
      prisma.conversation.findUnique.mockResolvedValue({
        id: 'conv-1',
        userAId: 'user-a',
        userBId: 'user-b',
      });
      prisma.user.findUnique.mockImplementation(({ where }: any) =>
        Promise.resolve({
          id: where.id,
          name: where.id,
          email: `${where.id}@test.ro`,
        }),
      );
      prisma.message.findMany.mockResolvedValue([
        {
          id: 'msg-1',
          senderId: 'user-b',
          content: 'ceva nepotrivit',
          photo: null,
          location: null,
          locationLat: null,
          locationLng: null,
          meetingAt: null,
          priceOfferId: null,
          createdAt: new Date('2026-01-01T10:00:00.000Z'),
        },
      ]);
      prisma.report.create.mockResolvedValue({ id: 'report-1' });
    });

    it('exportă transcriptul în folderul chat-reports și îl leagă de raport', async () => {
      await service.reportConversation('conv-1', 'user-a', {
        reason: 'HARASSMENT',
      });

      expect(storage.uploadTextFile).toHaveBeenCalledWith(
        expect.stringContaining('ceva nepotrivit'),
        'chat-reports',
        'conversatie-conv-1',
      );
      // Transcriptul conține conversația privată a doi useri, deci linkul din
      // emailul de moderare trebuie să fie semnat și expirabil. `getPublicUrl`
      // ar produce un URL permanent, către un obiect care oricum nu mai e
      // citibil anonim (vezi PUBLIC_PREFIXES) - deci linkul ar și pica.
      expect(storage.getSignedUrl).toHaveBeenCalledWith('chat-reports/x.txt');
      expect(storage.getPublicUrl).not.toHaveBeenCalledWith(
        'chat-reports/x.txt',
      );
      expect(prisma.report.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          reporterId: 'user-a',
          reportedUserId: 'user-b',
          conversationId: 'conv-1',
          transcriptPath: 'chat-reports/x.txt',
        }),
      });
      expect(mail.sendChatReportNotification).toHaveBeenCalled();
    });

    it('nu pierde raportul dacă emailul de moderare eșuează', async () => {
      mail.sendChatReportNotification.mockRejectedValue(
        new Error('resend down'),
      );

      const result = await service.reportConversation('conv-1', 'user-a', {
        reason: 'SPAM',
      });

      expect(result.reportId).toBe('report-1');
    });
  });
});

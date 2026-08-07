import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from './notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../common/realtime/realtime.service';
import { PushService } from './push.service';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let prisma: {
    notification: Record<string, jest.Mock>;
  };
  let realtime: { emitToUser: jest.Mock };
  let push: { sendToUser: jest.Mock };

  beforeEach(async () => {
    prisma = {
      notification: {
        create: jest.fn(),
        findMany: jest.fn(),
        updateMany: jest.fn(),
      },
    };
    realtime = { emitToUser: jest.fn() };
    push = { sendToUser: jest.fn().mockResolvedValue(undefined) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: RealtimeService, useValue: realtime },
        { provide: PushService, useValue: push },
      ],
    }).compile();

    service = module.get(NotificationsService);
  });

  it('creeaza o notificare cu payload-ul dat', async () => {
    prisma.notification.create.mockResolvedValue({ id: 'notif-1' });

    await service.create('user-1', 'NEW_MESSAGE', 'Ai un mesaj nou', {
      conversationId: 'c-1',
    });

    expect(prisma.notification.create).toHaveBeenCalledWith({
      data: {
        userId: 'user-1',
        type: 'NEW_MESSAGE',
        message: 'Ai un mesaj nou',
        data: { conversationId: 'c-1' },
      },
    });
  });

  it('impinge notificarea creata live catre user, pe socket', async () => {
    prisma.notification.create.mockResolvedValue({ id: 'notif-1' });

    await service.create('user-1', 'NEW_MESSAGE', 'Ai un mesaj nou');

    expect(realtime.emitToUser).toHaveBeenCalledWith('user-1', 'notification', {
      id: 'notif-1',
    });
  });

  it('returneaza notificarile unui user, ordonate descrescator, max 50', async () => {
    prisma.notification.findMany.mockResolvedValue([]);

    await service.getMine('user-1');

    expect(prisma.notification.findMany).toHaveBeenCalledWith({
      where: { userId: 'user-1' },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  });

  it('marcheaza o notificare specifica ca citita, scopata pe user', async () => {
    prisma.notification.updateMany.mockResolvedValue({ count: 1 });

    const result = await service.markAsRead('notif-1', 'user-1');

    expect(prisma.notification.updateMany).toHaveBeenCalledWith({
      where: { id: 'notif-1', userId: 'user-1' },
      data: { isRead: true },
    });
    expect(result.message).toContain('citită');
  });

  it('marcheaza toate notificarile necitite ale unui user', async () => {
    prisma.notification.updateMany.mockResolvedValue({ count: 3 });

    await service.markAllAsRead('user-1');

    expect(prisma.notification.updateMany).toHaveBeenCalledWith({
      where: { userId: 'user-1', isRead: false },
      data: { isRead: true },
    });
  });
});

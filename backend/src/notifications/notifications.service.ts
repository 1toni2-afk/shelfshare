import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationType, Prisma } from '@prisma/client';
import { RealtimeService } from '../common/realtime/realtime.service';

@Injectable()
export class NotificationsService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
  ) {}

  async create(
    userId: string,
    type: NotificationType,
    message: string,
    data?: Record<string, unknown>,
  ) {
    const notification = await this.prisma.notification.create({
      data: {
        userId,
        type,
        message,
        data: data as Prisma.InputJsonValue,
      },
    });

    // Împinge notificarea live către user, ca clopoțelul și buleta de necitite
    // să se actualizeze fără refresh de pagină. Dacă userul nu e conectat pe
    // socket, se pierde - o va vedea oricum la următoarea încărcare (GET /mine).
    this.realtime.emitToUser(userId, 'notification', notification);

    return notification;
  }

  getMine(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markAsRead(id: string, userId: string) {
    await this.prisma.notification.updateMany({
      where: { id, userId },
      data: { isRead: true },
    });
    return { message: 'Marcată ca citită' };
  }

  async markAllAsRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { message: 'Toate marcate ca citite' };
  }
}

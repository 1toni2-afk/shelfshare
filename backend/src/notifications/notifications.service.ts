import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationType, Prisma } from '@prisma/client';
import { RealtimeService } from '../common/realtime/realtime.service';
import { PushService } from './push.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private push: PushService,
  ) {}

  /**
   * Push-ul e mereu best-effort: userul deja are notificarea în DB și pe
   * socket cât timp ajungem aici, deci o eroare la FCM (token expirat,
   * Firebase nesetat, offline) nu trebuie să afecteze restul fluxului.
   *
   * `type` și `data` merg în payload-ul de date al mesajului FCM, nu doar în
   * rândul din DB: aplicația calculează din ele unde să ducă tap-ul pe
   * notificarea de sistem (vezi frontend/lib/core/notifications/
   * notification_route.dart). Fără ele, un tap pe „ai primit un mesaj"
   * deschidea doar aplicația, pe ecranul de start.
   */
  private sendPushSafe(
    userId: string,
    message: string,
    type: NotificationType,
    data?: Record<string, unknown>,
  ) {
    this.push
      .sendToUser(userId, 'ShelfShare', message, buildPushData(type, data))
      .catch((error) => {
        this.logger.warn(`Push eșuat pentru ${userId}: ${error}`);
      });
  }

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
    this.sendPushSafe(userId, message, type, data);

    return notification;
  }

  /**
   * Pentru evenimente care se pot repeta rapid (ex. mai multe mesaje
   * consecutive într-o conversație): dacă mai există deja o notificare
   * necitită cu același `dedupeKey` în `data`, o actualizăm (text + oră) în
   * loc să creăm un rând nou - userul primește o singură notificare per
   * conversație, nu una per mesaj.
   */
  async upsertUnread(
    userId: string,
    type: NotificationType,
    message: string,
    data: Record<string, unknown>,
    dedupeField: string,
  ) {
    const dedupeValue = data[dedupeField];
    const existing = await this.prisma.notification.findFirst({
      where: {
        userId,
        type,
        isRead: false,
        data: { path: [dedupeField], equals: dedupeValue as Prisma.InputJsonValue },
      },
      orderBy: { createdAt: 'desc' },
    });

    const notification = existing
      ? await this.prisma.notification.update({
          where: { id: existing.id },
          data: {
            message,
            data: data as Prisma.InputJsonValue,
            createdAt: new Date(),
          },
        })
      : await this.prisma.notification.create({
          data: { userId, type, message, data: data as Prisma.InputJsonValue },
        });

    this.realtime.emitToUser(userId, 'notification', notification);
    // Push doar la prima notificare necitită din grup - altfel 10 mesaje
    // consecutive ar da 10 push-uri, exact ce dedup-ul ăsta încearcă să evite.
    if (!existing) this.sendPushSafe(userId, message, type, data);
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

  /**
   * Marchează ca citite notificările necitite ale unui user care au un anumit
   * câmp în `data` egal cu o valoare dată - ex. toate notificările „mesaj nou"
   * pentru o conversație, când userul deschide acea conversație.
   */
  async markAsReadByDataField(
    userId: string,
    type: NotificationType,
    dedupeField: string,
    dedupeValue: unknown,
  ) {
    const { count } = await this.prisma.notification.updateMany({
      where: {
        userId,
        type,
        isRead: false,
        data: { path: [dedupeField], equals: dedupeValue as Prisma.InputJsonValue },
      },
      data: { isRead: true },
    });

    // Fără acest event, clopoțelul rămâne cu badge-ul vechi până la următorul
    // reload manual - userul deschide conversația, mesajele devin citite, dar
    // notificarea din clopoțel pare tot necitită.
    if (count > 0) {
      this.realtime.emitToUser(userId, 'notification_read', { type, dedupeField, dedupeValue });
    }
  }

  async markAllAsRead(userId: string) {
    await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { message: 'Toate marcate ca citite' };
  }
}

/**
 * FCM acceptă în `data` doar perechi string-string - orice altceva e respins
 * de SDK la trimitere. Serializăm deci fiecare valoare, sărind peste null:
 * o cheie absentă și una cu textul "null" nu înseamnă același lucru pentru
 * client, care decide destinația după prezența cheii.
 *
 * Obiectele/array-urile ajung JSON, ca să nu devină tăcut "[object Object]" -
 * niciun tip de notificare nu rutează după ele astăzi, dar o valoare citibilă
 * face diferența când se depanează un payload.
 */
function buildPushData(
  type: NotificationType,
  data?: Record<string, unknown>,
): Record<string, string> {
  const payload: Record<string, string> = { type };
  for (const [key, value] of Object.entries(data ?? {})) {
    if (value === null || value === undefined) continue;
    payload[key] =
      typeof value === 'object' ? JSON.stringify(value) : String(value);
  }
  return payload;
}

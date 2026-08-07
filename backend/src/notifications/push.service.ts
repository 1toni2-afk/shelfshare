import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { initializeApp, cert, App, ServiceAccount } from 'firebase-admin/app';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Trimite push notifications prin Firebase Cloud Messaging. Degradează
 * silențios (log un singur warning, apoi no-op) dacă FIREBASE_SERVICE_ACCOUNT
 * nu e setat - proiectul Firebase e o resursă externă pe care userul trebuie
 * să o creeze manual (necesită cont Google + consolă web), deci push-ul
 * trebuie să rămână opțional și să nu blocheze restul aplicației dacă lipsește.
 */
@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private app: App | null = null;
  private messaging: Messaging | null = null;
  private warnedMissingConfig = false;

  constructor(
    private config: ConfigService,
    private prisma: PrismaService,
  ) {}

  onModuleInit() {
    const raw = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    if (!raw) return;

    try {
      const serviceAccount = JSON.parse(raw) as ServiceAccount;
      this.app = initializeApp({ credential: cert(serviceAccount) });
      this.messaging = getMessaging(this.app);
      this.logger.log('Firebase Admin inițializat - push notifications active.');
    } catch (error) {
      this.logger.error(
        `FIREBASE_SERVICE_ACCOUNT invalid (JSON neparsabil) - push notifications dezactivate: ${error}`,
      );
    }
  }

  private get enabled() {
    if (this.messaging) return true;
    if (!this.warnedMissingConfig) {
      this.warnedMissingConfig = true;
      this.logger.warn(
        'FIREBASE_SERVICE_ACCOUNT nesetat - push notifications dezactivate (userii primesc doar notificarea din clopoțel).',
      );
    }
    return false;
  }

  async registerToken(userId: string, token: string, platform: string) {
    await this.prisma.deviceToken.upsert({
      where: { token },
      create: { userId, token, platform },
      // Un token FCM poate migra de la un cont la altul pe același telefon
      // (logout + login cu alt user) - upsert-ul mută proprietarul, nu doar
      // reface rândul existent.
      update: { userId, platform },
    });
  }

  async unregisterToken(token: string) {
    await this.prisma.deviceToken.deleteMany({ where: { token } });
  }

  /**
   * Trimite push tuturor dispozitivelor userului. Token-urile care nu mai
   * sunt valide (dezinstalare, logout de mult timp) sunt curățate automat pe
   * baza codului de eroare întors de FCM, ca tabela să nu crească la infinit
   * cu token-uri moarte.
   */
  async sendToUser(userId: string, title: string, body: string, data?: Record<string, string>) {
    if (!this.enabled) return;

    const tokens = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    if (tokens.length === 0) return;

    const response = await this.messaging!.sendEachForMulticast({
      tokens: tokens.map((t) => t.token),
      notification: { title, body },
      data,
    });

    const deadTokens: string[] = [];
    response.responses.forEach((result, i) => {
      const code = result.error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        deadTokens.push(tokens[i].token);
      }
    });
    if (deadTokens.length > 0) {
      await this.prisma.deviceToken.deleteMany({ where: { token: { in: deadTokens } } });
    }
  }
}

import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Cine e online chiar acum, ținut în memorie (nu în DB) - o stare care se
 * schimbă la fiecare deschidere/închidere de aplicație nu merită un write pe
 * disc, iar dacă procesul repornește toată lumea apare corect ca offline până
 * se reconectează.
 *
 * Consecință de scalare: la mai multe instanțe de backend, fiecare ar ști doar
 * despre socket-urile ei. Momentan rulăm un singur proces (vezi
 * docker-compose.prod.yml); la sharding, harta asta trebuie mutată în Redis.
 *
 * Contorizăm conexiunile, nu userii: aceeași persoană poate avea aplicația
 * deschisă pe telefon și în browser, iar închiderea uneia nu înseamnă offline.
 */
@Injectable()
export class PresenceService {
  private readonly logger = new Logger(PresenceService.name);
  private readonly connections = new Map<string, number>();

  constructor(private prisma: PrismaService) {}

  /** @returns true dacă userul tocmai a trecut din offline în online. */
  addConnection(userId: string): boolean {
    const next = (this.connections.get(userId) ?? 0) + 1;
    this.connections.set(userId, next);
    return next === 1;
  }

  /** @returns true dacă userul tocmai a rămas fără nicio conexiune activă. */
  removeConnection(userId: string): boolean {
    const next = (this.connections.get(userId) ?? 1) - 1;
    if (next <= 0) {
      this.connections.delete(userId);
      return true;
    }
    this.connections.set(userId, next);
    return false;
  }

  isOnline(userId: string): boolean {
    return this.connections.has(userId);
  }

  /**
   * Scriem lastSeenAt doar la deconectarea completă - cât timp e online,
   * „Last seen" nu se afișează oricum, deci un update pe fiecare mesaj ar fi
   * trafic degeaba către DB.
   */
  async touchLastSeen(userId: string) {
    await this.prisma.user
      .update({ where: { id: userId }, data: { lastSeenAt: new Date() } })
      .catch((error) =>
        this.logger.warn(`Nu am putut seta lastSeenAt pentru ${userId}: ${error}`),
      );
  }
}

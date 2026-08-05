import { Injectable, Logger } from '@nestjs/common';
import { Server } from 'socket.io';

/**
 * Punte subțire între serviciile obișnuite (care nu au acces la socket.io) și
 * serverul socket deținut de ChatGateway. Gateway-ul își înregistrează serverul
 * la pornire (`registerServer`), iar orice serviciu poate emite apoi către un
 * user prin `emitToUser`, fără să depindă de ChatModule.
 *
 * Motivul existenței: ChatModule importă deja NotificationsModule, deci
 * NotificationsService nu poate injecta ChatGateway direct (dependență
 * circulară). Acest serviciu, marcat global, rupe cercul - nu depinde de nimic.
 */
@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);

  /** Serverul namespace-ului /chat, setat de ChatGateway în afterInit. */
  private server?: Server;

  registerServer(server: Server) {
    this.server = server;
  }

  /**
   * Emite un eveniment în camera personală a userului (`user:<id>`), aceeași în
   * care ChatGateway îl bagă la conectare. Dacă serverul nu e încă pornit sau
   * userul nu are niciun socket deschis, evenimentul se pierde în tăcere -
   * exact ca la orice notificare push: sursa de adevăr rămâne baza de date, pe
   * care clientul o reîncarcă la deschidere.
   */
  emitToUser(userId: string, event: string, payload: unknown) {
    if (!this.server) {
      this.logger.warn(
        `emitToUser fără server înregistrat (event ${event}, user ${userId})`,
      );
      return;
    }
    this.server.to(`user:${userId}`).emit(event, payload);
  }
}

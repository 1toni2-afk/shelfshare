import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConversationsService } from './conversations.service';
import { PresenceService } from './presence.service';
import { SendMessageDto } from './dto/send-message.dto';
import { RealtimeService } from '../common/realtime/realtime.service';
import { corsOrigin } from '../common/utils/cors-origin';
import { SlidingWindowLimiterService } from '../common/rate-limit/sliding-window-limiter.service';

interface AuthenticatedSocket extends Socket {
  data: { userId: string };
}

const SEND_MESSAGE_LIMIT = 20;
const SEND_MESSAGE_WINDOW_MS = 10_000;

@WebSocketGateway({
  cors: { origin: corsOrigin },
  namespace: 'chat',
})
export class ChatGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(ChatGateway.name);

  @WebSocketServer()
  server: Server;

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
    private conversations: ConversationsService,
    private presence: PresenceService,
    private realtime: RealtimeService,
    private rateLimiter: SlidingWindowLimiterService,
  ) {}

  // Punem serverul namespace-ului /chat la dispoziția serviciilor care nu au
  // acces la socket.io (ex. NotificationsService), ca notificările create în
  // orice modul să poată fi împinse live către user, pe același socket.
  afterInit(server: Server) {
    this.realtime.registerServer(server);
  }

  async handleConnection(client: AuthenticatedSocket) {
    try {
      const token = client.handshake.auth?.token as string | undefined;
      if (!token) throw new UnauthorizedException();

      const payload = this.jwt.verify<{ sub: string }>(token, {
        secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      });

      client.data.userId = payload.sub;
      await client.join(`user:${payload.sub}`);

      if (this.presence.addConnection(payload.sub)) {
        await this.broadcastPresence(payload.sub, true);
      }

      this.logger.log(`Client conectat: user ${payload.sub}`);
    } catch {
      this.logger.warn('Conexiune respinsă: token invalid sau lipsă');
      client.disconnect();
    }
  }

  async handleDisconnect(client: AuthenticatedSocket) {
    const userId = client.data?.userId;
    this.logger.log(`Client deconectat: user ${userId}`);
    if (!userId) return;

    // Doar când s-a închis și ultima conexiune a userului - altfel a doua
    // filă din browser l-ar arăta offline deși aplicația e încă deschisă.
    if (this.presence.removeConnection(userId)) {
      await this.presence.touchLastSeen(userId);
      await this.broadcastPresence(userId, false);
    }
  }

  @SubscribeMessage('join_conversation')
  async joinConversation(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() conversationId: string,
  ) {
    const participants =
      await this.conversations.getParticipants(conversationId);
    if (!participants.includes(client.data.userId)) {
      return { error: 'Nu faci parte din această conversație' };
    }
    await client.join(`conversation:${conversationId}`);

    // Starea celuilalt la deschiderea chatului: fără asta, antetul ar arăta
    // „offline" până la următoarea lui conectare sau deconectare.
    const otherUserId = participants.find((id) => id !== client.data.userId);
    return {
      joined: conversationId,
      otherUserOnline: otherUserId
        ? this.presence.isOnline(otherUserId)
        : false,
    };
  }

  @SubscribeMessage('send_message')
  async handleMessage(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() dto: SendMessageDto,
  ) {
    // Guard-ul HTTP (HttpThrottlerGuard) sare peste contextele WS - fără
    // asta, send_message n-ar avea nicio limită de spam.
    if (
      !this.rateLimiter.consume(
        `send_message:${client.data.userId}`,
        SEND_MESSAGE_LIMIT,
        SEND_MESSAGE_WINDOW_MS,
      )
    ) {
      return { error: 'Trimiți mesaje prea repede - așteaptă puțin' };
    }

    // Global ValidationPipe nu se aplică peste gateway-urile WS din NestJS,
    // așa că validăm manual câmpurile cheie. Fără asta, un `locationLat`
    // trimis ca string (din browser) sau lipsa unuia dintre lat/lng ar cădea
    // la insert Prisma cu o eroare generică pe care clientul o vede doar ca
    // „Verifică conexiunea".
    const validationError = this.validateSendMessage(dto);
    if (validationError) {
      this.logger.warn(
        `send_message respins pentru user ${client.data.userId}: ${validationError}`,
      );
      return { error: validationError };
    }

    try {
      const message = await this.conversations.sendMessage(
        client.data.userId,
        dto,
      );

      this.server
        .to(`conversation:${dto.conversationId}`)
        .emit('new_message', message);

      const participants = await this.conversations.getParticipants(
        dto.conversationId,
      );
      const otherUserId = participants.find((id) => id !== client.data.userId);
      if (otherUserId) {
        this.server.to(`user:${otherUserId}`).emit('message_notification', {
          conversationId: dto.conversationId,
          message,
        });
      }

      return message;
    } catch (error) {
      // Prinderea explicită a excepțiilor face diferența între „a picat rețeaua"
      // și „serverul a refuzat mesajul" pentru client - și lasă un log utilizabil.
      const detail =
        error instanceof Error
          ? `${error.name}: ${error.message}`
          : String(error);
      this.logger.error(
        `send_message a eșuat pentru user ${client.data.userId} (conv ${dto.conversationId}): ${detail}`,
      );
      return { error: 'Serverul nu a putut salva mesajul' };
    }
  }

  /**
   * Verificări minime pe payload-ul de send_message. Returnează un mesaj de
   * eroare dacă ceva e greșit; null dacă e valid.
   */
  private validateSendMessage(dto: SendMessageDto): string | null {
    if (!dto.conversationId || typeof dto.conversationId !== 'string') {
      return 'conversationId lipsă';
    }
    if (!dto.content && !dto.location) {
      return 'Mesaj gol: nici text, nici locație';
    }
    // Locația trebuie completă: nume + coordonate. Fără asta, harta nu ar
    // funcționa iar întâlnirea nu ar putea fi găsită.
    if (dto.location) {
      if (
        typeof dto.locationLat !== 'number' ||
        typeof dto.locationLng !== 'number' ||
        Number.isNaN(dto.locationLat) ||
        Number.isNaN(dto.locationLng)
      ) {
        return 'Locația nu are coordonate valide';
      }
      if (
        dto.locationLat < -90 ||
        dto.locationLat > 90 ||
        dto.locationLng < -180 ||
        dto.locationLng > 180
      ) {
        return 'Coordonatele locației sunt în afara intervalului';
      }
    }
    if (dto.meetingAt) {
      const parsed = new Date(dto.meetingAt);
      if (Number.isNaN(parsed.getTime())) {
        return 'meetingAt nu este o dată validă';
      }
    }
    return null;
  }

  /**
   * Difuzează un mesaj creat în afara socket-ului (pozele urcă prin HTTP, ca
   * orice upload de fișier). Fără asta, destinatarul ar afla de poză abia la
   * următoarea reîncărcare a conversației.
   */
  async broadcastMessage(
    conversationId: string,
    senderId: string,
    message: unknown,
  ) {
    this.server
      .to(`conversation:${conversationId}`)
      .emit('new_message', message);

    const participants =
      await this.conversations.getParticipants(conversationId);
    const otherUserId = participants.find((id) => id !== senderId);
    if (otherUserId) {
      this.server
        .to(`user:${otherUserId}`)
        .emit('message_notification', { conversationId, message });
    }
  }

  /**
   * Confirmarea de citire vine pe socket, nu doar prin POST /read, ca
   * expeditorul să vadă „Văzut" imediat, cât ține conversația deschisă.
   */
  @SubscribeMessage('mark_read')
  async handleMarkRead(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() conversationId: string,
  ) {
    const result = await this.conversations.markAsRead(
      conversationId,
      client.data.userId,
    );

    if (result.markedCount > 0) {
      client.to(`conversation:${conversationId}`).emit('messages_read', {
        conversationId,
        readerId: client.data.userId,
      });
    }

    return result;
  }

  @SubscribeMessage('typing')
  handleTyping(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() conversationId: string,
  ) {
    client
      .to(`conversation:${conversationId}`)
      .emit('user_typing', { userId: client.data.userId, conversationId });
  }

  /**
   * Prezența se difuzează țintit, doar către cei cu care userul chiar are o
   * conversație - un broadcast global ar spune tuturor când e online oricine.
   */
  private async broadcastPresence(userId: string, isOnline: boolean) {
    try {
      const partnerIds = await this.conversations.getChatPartnerIds(userId);
      const payload = {
        userId,
        isOnline,
        lastSeenAt: isOnline ? null : new Date().toISOString(),
      };
      for (const partnerId of partnerIds) {
        this.server.to(`user:${partnerId}`).emit('user_presence', payload);
      }
    } catch (error) {
      this.logger.warn(
        `Nu am putut difuza prezența pentru ${userId}: ${error}`,
      );
    }
  }
}

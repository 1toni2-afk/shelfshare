import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
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

interface AuthenticatedSocket extends Socket {
  data: { userId: string };
}

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: 'chat',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(ChatGateway.name);

  @WebSocketServer()
  server: Server;

  constructor(
    private jwt: JwtService,
    private config: ConfigService,
    private conversations: ConversationsService,
    private presence: PresenceService,
  ) {}

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
    this.server.to(`conversation:${conversationId}`).emit('new_message', message);

    const participants = await this.conversations.getParticipants(conversationId);
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
      this.logger.warn(`Nu am putut difuza prezența pentru ${userId}: ${error}`);
    }
  }
}

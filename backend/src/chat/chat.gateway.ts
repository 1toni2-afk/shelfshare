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

      this.logger.log(`Client conectat: user ${payload.sub}`);
    } catch {
      this.logger.warn('Conexiune respinsă: token invalid sau lipsă');
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthenticatedSocket) {
    this.logger.log(`Client deconectat: user ${client.data?.userId}`);
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
    return { joined: conversationId };
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

  @SubscribeMessage('typing')
  handleTyping(
    @ConnectedSocket() client: AuthenticatedSocket,
    @MessageBody() conversationId: string,
  ) {
    client
      .to(`conversation:${conversationId}`)
      .emit('user_typing', { userId: client.data.userId, conversationId });
  }
}

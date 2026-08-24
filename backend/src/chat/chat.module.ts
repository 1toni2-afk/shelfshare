import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { ChatGateway } from './chat.gateway';
import { PresenceService } from './presence.service';
import { StorageModule } from '../storage/storage.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { SafetyModule } from '../safety/safety.module';
import { MailModule } from '../mail/mail.module';
import { RateLimitModule } from '../common/rate-limit/rate-limit.module';
import { RevokedTokenModule } from '../common/security/revoked-token.module';

@Module({
  imports: [
    StorageModule,
    JwtModule.register({}),
    NotificationsModule,
    SafetyModule,
    MailModule,
    RateLimitModule,
    // Nest refolosește aceeași instanță de modul, deci lista de token-uri
    // revocate e comună cu cea din AuthModule - un logout pe HTTP e văzut și
    // de gateway.
    RevokedTokenModule,
  ],
  controllers: [ConversationsController],
  providers: [ConversationsService, ChatGateway, PresenceService],
  exports: [ConversationsService],
})
export class ChatModule {}

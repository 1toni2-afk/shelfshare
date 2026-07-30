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

@Module({
  imports: [
    StorageModule,
    JwtModule.register({}),
    NotificationsModule,
    SafetyModule,
    MailModule,
  ],
  controllers: [ConversationsController],
  providers: [ConversationsService, ChatGateway, PresenceService],
  exports: [ConversationsService],
})
export class ChatModule {}

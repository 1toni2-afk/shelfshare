import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { ChatGateway } from './chat.gateway';
import { StorageModule } from '../storage/storage.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { SafetyModule } from '../safety/safety.module';

@Module({
  imports: [
    StorageModule,
    JwtModule.register({}),
    NotificationsModule,
    SafetyModule,
  ],
  controllers: [ConversationsController],
  providers: [ConversationsService, ChatGateway],
})
export class ChatModule {}

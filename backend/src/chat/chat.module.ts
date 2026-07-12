import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConversationsController } from './conversations.controller';
import { ConversationsService } from './conversations.service';
import { ChatGateway } from './chat.gateway';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [StorageModule, JwtModule.register({})],
  controllers: [ConversationsController],
  providers: [ConversationsService, ChatGateway],
})
export class ChatModule {}

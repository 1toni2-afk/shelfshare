import { Module } from '@nestjs/common';
import { AdminChatController } from './admin-chat.controller';
import { AdminChatService } from './admin-chat.service';
import { AdminModule } from '../admin/admin.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [AdminModule, NotificationsModule],
  controllers: [AdminChatController],
  providers: [AdminChatService],
})
export class AdminChatModule {}

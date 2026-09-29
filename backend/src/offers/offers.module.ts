import { Module } from '@nestjs/common';
import { OffersController } from './offers.controller';
import { OffersService } from './offers.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { ChatModule } from '../chat/chat.module';
import { ListingScoreModule } from '../books/listing-score.module';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [NotificationsModule, ChatModule, ListingScoreModule, StorageModule],
  controllers: [OffersController],
  providers: [OffersService],
})
export class OffersModule {}

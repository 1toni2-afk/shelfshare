import { Module } from '@nestjs/common';
import { WishlistController } from './wishlist.controller';
import { WishlistService } from './wishlist.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { ListingScoreModule } from '../books/listing-score.module';

@Module({
  imports: [NotificationsModule, ListingScoreModule],
  controllers: [WishlistController],
  providers: [WishlistService],
  exports: [WishlistService],
})
export class WishlistModule {}

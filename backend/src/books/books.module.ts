import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { BooksController } from './books.controller';
import { BooksService } from './books.service';
import { BookLookupService } from './book-lookup.service';
import { StorageModule } from '../storage/storage.module';
import { WishlistModule } from '../wishlist/wishlist.module';
import { FollowModule } from '../follow/follow.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ListingScoreModule } from './listing-score.module';
import { SavedSearchesModule } from '../saved-searches/saved-searches.module';
import { ReviewsModule } from '../reviews/reviews.module';

@Module({
  imports: [
    HttpModule.register({ timeout: 8000 }),
    StorageModule,
    WishlistModule,
    ListingScoreModule,
    FollowModule,
    NotificationsModule,
    SavedSearchesModule,
    // Pagina operei adună recenziile peste toate edițiile - vezi getWork.
    ReviewsModule,
  ],
  controllers: [BooksController],
  providers: [BooksService, BookLookupService],
})
export class BooksModule {}

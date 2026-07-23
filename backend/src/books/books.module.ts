import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { BooksController } from './books.controller';
import { BooksService } from './books.service';
import { BookLookupService } from './book-lookup.service';
import { StorageModule } from '../storage/storage.module';
import { WishlistModule } from '../wishlist/wishlist.module';
import { FollowModule } from '../follow/follow.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    HttpModule.register({ timeout: 8000 }),
    StorageModule,
    WishlistModule,
    FollowModule,
    NotificationsModule,
  ],
  controllers: [BooksController],
  providers: [BooksService, BookLookupService],
})
export class BooksModule {}

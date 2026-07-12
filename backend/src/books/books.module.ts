import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { BooksController } from './books.controller';
import { BooksService } from './books.service';
import { BookLookupService } from './book-lookup.service';
import { StorageModule } from '../storage/storage.module';
import { WishlistModule } from '../wishlist/wishlist.module';

@Module({
  imports: [
    HttpModule.register({ timeout: 8000 }),
    StorageModule,
    WishlistModule,
  ],
  controllers: [BooksController],
  providers: [BooksService, BookLookupService],
})
export class BooksModule {}

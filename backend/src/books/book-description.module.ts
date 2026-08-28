import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { BookDescriptionService } from './book-description.service';

/**
 * Modul separat de BooksModule intenționat: BookDescriptionService e nevoie și
 * în BookshelfModule, iar BooksModule trage după el StorageModule, WishlistModule,
 * FollowModule, NotificationsModule etc. - dependențe pe care raftul nu le are.
 */
@Module({
  imports: [HttpModule.register({ timeout: 8000 })],
  providers: [BookDescriptionService],
  exports: [BookDescriptionService],
})
export class BookDescriptionModule {}

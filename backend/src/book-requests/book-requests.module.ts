import { Module } from '@nestjs/common';
import { BookRequestsController } from './book-requests.controller';
import { BookRequestsService } from './book-requests.service';
import { WorkerTokenGuard } from './guards/worker-token.guard';
import { BooksModule } from '../books/books.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AdminModule } from '../admin/admin.module';

@Module({
  // BooksModule pentru căutarea în catalogul propriu (BooksService) și la
  // providerii externi (BookLookupService) - aceleași surse ca autocomplete-ul
  // care n-a găsit cartea, ca să nu existe două comportamente de căutare.
  imports: [BooksModule, NotificationsModule, AdminModule],
  controllers: [BookRequestsController],
  providers: [BookRequestsService, WorkerTokenGuard],
  exports: [BookRequestsService],
})
export class BookRequestsModule {}

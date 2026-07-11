import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { BooksController } from './books.controller';
import { BooksService } from './books.service';
import { BookLookupService } from './book-lookup.service';
import { StorageModule } from '../storage/storage.module';

@Module({
  imports: [HttpModule.register({ timeout: 8000 }), StorageModule],
  controllers: [BooksController],
  providers: [BooksService, BookLookupService],
})
export class BooksModule {}

import { Module } from '@nestjs/common';
import { BookshelfController } from './bookshelf.controller';
import { BookshelfService } from './bookshelf.service';
import { BookDescriptionModule } from '../books/book-description.module';

@Module({
  imports: [BookDescriptionModule],
  controllers: [BookshelfController],
  providers: [BookshelfService],
  exports: [BookshelfService],
})
export class BookshelfModule {}

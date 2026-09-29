import { Module } from '@nestjs/common';
import {
  BookMatchController,
  BookMatchPublicController,
} from './book-match.controller';
import { BookMatchService } from './book-match.service';

@Module({
  controllers: [BookMatchController, BookMatchPublicController],
  providers: [BookMatchService],
  exports: [BookMatchService],
})
export class BookMatchModule {}

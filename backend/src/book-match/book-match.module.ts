import { Module } from '@nestjs/common';
import { BookMatchController } from './book-match.controller';
import { BookMatchService } from './book-match.service';

@Module({
  controllers: [BookMatchController],
  providers: [BookMatchService],
  exports: [BookMatchService],
})
export class BookMatchModule {}

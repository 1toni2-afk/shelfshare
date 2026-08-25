import { Module } from '@nestjs/common';
import { BookOfMonthController } from './book-of-month.controller';
import { BookOfMonthService } from './book-of-month.service';

@Module({
  controllers: [BookOfMonthController],
  providers: [BookOfMonthService],
})
export class BookOfMonthModule {}

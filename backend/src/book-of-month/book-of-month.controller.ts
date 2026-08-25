import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { BookOfMonthService } from './book-of-month.service';
import { VoteBookOfMonthDto } from './dto/vote-book-of-month.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@Controller('book-of-month')
export class BookOfMonthController {
  constructor(private bookOfMonthService: BookOfMonthService) {}

  @Get('winner')
  getCurrentWinner() {
    return this.bookOfMonthService.getCurrentWinner();
  }

  @UseGuards(JwtAuthGuard)
  @Get('my-vote')
  getMyVote(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookOfMonthService.getMyVote(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Post('vote')
  vote(@Req() req: Request, @Body() dto: VoteBookOfMonthDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookOfMonthService.vote(userId!, dto.bookId);
  }
}

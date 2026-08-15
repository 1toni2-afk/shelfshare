import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { BookMatchService } from './book-match.service';
import { QueueQueryDto } from './dto/queue-query.dto';
import { SwipeDto } from './dto/swipe.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('book-match')
export class BookMatchController {
  constructor(private bookMatch: BookMatchService) {}

  @Get('queue')
  queue(@Req() req: Request, @Query() query: QueueQueryDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookMatch.getQueue(userId!, query.sessionId, query.size ?? 20);
  }

  @Post('swipe')
  swipe(@Req() req: Request, @Body() dto: SwipeDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookMatch.recordSwipe(userId!, dto);
  }

  @Post('recalibrate')
  recalibrate(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookMatch.recalibrate(userId!);
  }

  @Get('status')
  status(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookMatch.getStatus(userId!);
  }
}

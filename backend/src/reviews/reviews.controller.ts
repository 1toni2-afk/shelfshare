import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { ReviewsService } from './reviews.service';
import { UpsertReviewDto } from './dto/upsert-review.dto';
import { ReportReviewDto } from './dto/report-review.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@Controller('reviews')
export class ReviewsController {
  constructor(private reviewsService: ReviewsService) {}

  @Get('book/:bookId')
  getForBook(@Param('bookId') bookId: string) {
    return this.reviewsService.getForBook(bookId);
  }

  @UseGuards(OptionalJwtAuthGuard)
  @Get('book/:bookId/mine')
  getMine(@Req() req: Request, @Param('bookId') bookId: string) {
    const user = req.user as AuthenticatedUser | undefined;
    if (!user?.userId) return null;
    return this.reviewsService.getMine(user.userId, bookId);
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  upsert(@Req() req: Request, @Body() dto: UpsertReviewDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.reviewsService.upsert(userId!, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':bookId')
  remove(@Req() req: Request, @Param('bookId') bookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.reviewsService.remove(userId!, bookId);
  }

  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 3_600_000 } })
  @Post(':id/report')
  reportReview(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: ReportReviewDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.reviewsService.reportReview(id, userId!, dto);
  }
}

import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { FeedbackService } from './feedback.service';
import { CreateFeedbackDto } from './dto/create-feedback.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('feedback')
export class FeedbackController {
  constructor(private feedbackService: FeedbackService) {}

  @Post()
  create(@Req() req: Request, @Body() dto: CreateFeedbackDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.feedbackService.create(userId!, dto.message);
  }
}

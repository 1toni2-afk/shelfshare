import {
  Body,
  Controller,
  Get,
  Param,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { ReadingProgressService } from './reading-progress.service';
import { SetReadingProgressDto } from './dto/set-reading-progress.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('reading-progress')
export class ReadingProgressController {
  constructor(private readingProgressService: ReadingProgressService) {}

  @Get()
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.readingProgressService.getMyProgress(userId!);
  }

  @Get(':bookId')
  getForBook(@Req() req: Request, @Param('bookId') bookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.readingProgressService.getProgress(userId!, bookId);
  }

  @Put(':bookId')
  setForBook(
    @Req() req: Request,
    @Param('bookId') bookId: string,
    @Body() dto: SetReadingProgressDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.readingProgressService.setProgress(
      userId!,
      bookId,
      dto.currentPage,
      dto.totalPages,
    );
  }
}

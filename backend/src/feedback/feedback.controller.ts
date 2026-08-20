import {
  BadRequestException,
  Body,
  Controller,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { FeedbackService } from './feedback.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_PHOTO_SIZE_BYTES = 8 * 1024 * 1024;

@UseGuards(JwtAuthGuard)
@Controller('feedback')
export class FeedbackController {
  constructor(private feedbackService: FeedbackService) {}

  // `@Body() dto: CreateFeedbackDto` cu multipart era comportamentul de
  // dinainte de poze - cu FileInterceptor, câmpul text ajunge tot în
  // req.body, dar preferăm extragerea directă (ca la /conversations/:id/photos)
  // ca să nu depindem de cum se comportă ValidationPipe pe un body multipart.
  @Post()
  @UseInterceptors(
    FileInterceptor('photo', { limits: { fileSize: MAX_PHOTO_SIZE_BYTES } }),
  )
  create(
    @Req() req: Request,
    @Body('message') message: string,
    @UploadedFile() file?: Express.Multer.File,
  ) {
    if (!message || message.trim().length < 3 || message.length > 2000) {
      throw new BadRequestException('Mesajul trebuie să aibă între 3 și 2000 de caractere');
    }
    if (file) {
      if (file.size > MAX_PHOTO_SIZE_BYTES) {
        throw new BadRequestException('Poza este prea mare (maxim 8MB)');
      }
      if (!file.mimetype.startsWith('image/')) {
        throw new BadRequestException('Fișierul trebuie să fie o imagine');
      }
    }
    const { userId } = req.user as AuthenticatedUser;
    return this.feedbackService.create(userId!, message.trim(), file?.buffer);
  }
}

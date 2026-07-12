import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { ConversationsService } from './conversations.service';
import { StartConversationDto } from './dto/start-conversation.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_PHOTO_SIZE_BYTES = 8 * 1024 * 1024;

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class ConversationsController {
  constructor(private conversationsService: ConversationsService) {}

  @Post()
  start(@Req() req: Request, @Body() dto: StartConversationDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.findOrCreateConversation(
      userId!,
      dto.otherUserId,
    );
  }

  @Get()
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.getMyConversations(userId!);
  }

  @Get(':id/messages')
  getMessages(
    @Req() req: Request,
    @Param('id') id: string,
    @Query('before') before?: string,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.getMessages(id, userId!, 50, before);
  }

  @Post(':id/read')
  markAsRead(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.markAsRead(id, userId!);
  }

  @Post(':id/photos')
  @UseInterceptors(FileInterceptor('photo'))
  sendPhoto(
    @Req() req: Request,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('Nicio poză primită');
    }
    if (file.size > MAX_PHOTO_SIZE_BYTES) {
      throw new BadRequestException('Poza este prea mare (maxim 8MB)');
    }
    if (!file.mimetype.startsWith('image/')) {
      throw new BadRequestException('Fișierul trebuie să fie o imagine');
    }

    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.sendPhotoMessage(userId!, id, file.buffer);
  }
}

import {
  BadRequestException,
  Body,
  Controller,
  Delete,
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
import { ChatGateway } from './chat.gateway';
import { StartConversationDto } from './dto/start-conversation.dto';
import { ReportConversationDto } from './dto/report-conversation.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_PHOTO_SIZE_BYTES = 8 * 1024 * 1024;

@UseGuards(JwtAuthGuard)
@Controller('conversations')
export class ConversationsController {
  constructor(
    private conversationsService: ConversationsService,
    private chatGateway: ChatGateway,
  ) {}

  @Post()
  start(@Req() req: Request, @Body() dto: StartConversationDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.findOrCreateConversation(
      userId!,
      dto.otherUserId,
    );
  }

  @Get()
  getMine(@Req() req: Request, @Query('archived') archived?: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.getMyConversations(
      userId!,
      archived === 'true',
    );
  }

  @Get('unread-count')
  getUnreadCount(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.getUnreadCount(userId!);
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

  @Get(':id/messages/search')
  searchMessages(
    @Req() req: Request,
    @Param('id') id: string,
    @Query('q') query?: string,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.searchMessages(id, userId!, query ?? '');
  }

  @Post(':id/read')
  markAsRead(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.markAsRead(id, userId!);
  }

  /** Ștergere doar pentru mine - celălalt participant păstrează istoricul. */
  @Delete(':id')
  clear(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.clearConversation(id, userId!);
  }

  @Post(':id/archive')
  archive(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.setArchived(id, userId!, true);
  }

  @Delete(':id/archive')
  unarchive(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.setArchived(id, userId!, false);
  }

  @Post(':id/report')
  report(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: ReportConversationDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.conversationsService.reportConversation(id, userId!, dto);
  }

  @Post(':id/photos')
  @UseInterceptors(FileInterceptor('photo'))
  async sendPhoto(
    @Req() req: Request,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @Body('replyToId') replyToId?: string,
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
    const message = await this.conversationsService.sendPhotoMessage(
      userId!,
      id,
      file.buffer,
      replyToId || undefined,
    );

    // Pozele nu trec prin socket (sunt un upload HTTP), deci difuzarea către
    // conversație se face explicit aici.
    await this.chatGateway.broadcastMessage(id, userId!, message);

    return message;
  }
}

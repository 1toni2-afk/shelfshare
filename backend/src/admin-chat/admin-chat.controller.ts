import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { AdminChatService } from './admin-chat.service';
import { SendAdminChatMessageDto } from './dto/send-admin-chat-message.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from '../admin/guards/admin.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('admin-chat')
export class AdminChatController {
  constructor(private adminChatService: AdminChatService) {}

  // ---- Inbox-ul personal al userului ("chat with an admin") ----

  @Get('me')
  getMyConversation(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminChatService.getMyConversation(userId!);
  }

  @Post('me/messages')
  sendMyMessage(@Req() req: Request, @Body() dto: SendAdminChatMessageDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminChatService.sendMyMessage(userId!, dto.content);
  }

  @Post('me/read')
  markMyConversationRead(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminChatService.markMyConversationRead(userId!);
  }

  // ---- Inbox-ul de admin - vizibil oricărui admin, nu doar unuia asignat ----

  @UseGuards(AdminGuard)
  @Get('conversations')
  getAllConversations() {
    return this.adminChatService.getAllConversations();
  }

  @UseGuards(AdminGuard)
  @Get('conversations/:id/messages')
  getConversationMessages(@Param('id') id: string) {
    return this.adminChatService.getConversationMessages(id);
  }

  @UseGuards(AdminGuard)
  @Post('conversations/:id/messages')
  sendAdminReply(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: SendAdminChatMessageDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminChatService.sendAdminReply(id, userId!, dto.content);
  }

  @UseGuards(AdminGuard)
  @Post('conversations/:id/read')
  markConversationReadByAdmin(@Param('id') id: string) {
    return this.adminChatService.markConversationReadByAdmin(id);
  }
}

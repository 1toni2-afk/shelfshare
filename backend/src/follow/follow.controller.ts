import { Controller, Delete, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { FollowService } from './follow.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class FollowController {
  constructor(private followService: FollowService) {}

  // Înainte de ':id/follow', din același motiv ca 'browse' în books.controller.
  @Get('active')
  getActiveMembers() {
    return this.followService.getActiveMembers();
  }

  @Post(':id/follow')
  follow(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.followService.followUser(userId!, id);
  }

  @Delete(':id/follow')
  unfollow(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.followService.unfollowUser(userId!, id);
  }

  @Get(':id/follow')
  getStatus(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.followService.getFollowStatus(userId!, id);
  }
}

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
import type { Request } from 'express';
import { GroupsService } from './groups.service';
import { CreateGroupDto } from './dto/create-group.dto';
import { CreatePostDto } from './dto/create-post.dto';
import { CreateEventDto } from './dto/create-event.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@Controller('groups')
export class GroupsController {
  constructor(private groupsService: GroupsService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  create(@Req() req: Request, @Body() dto: CreateGroupDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.groupsService.createGroup(userId!, dto);
  }

  @Get('public')
  getPublic() {
    return this.groupsService.getPublicGroups();
  }

  @UseGuards(JwtAuthGuard)
  @Get('mine')
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.groupsService.getMyGroups(userId!);
  }

  @UseGuards(OptionalJwtAuthGuard)
  @Get(':id')
  getOne(@Req() req: Request, @Param('id') id: string) {
    const user = req.user as AuthenticatedUser | undefined;
    return this.groupsService.getGroup(id, user?.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/join')
  join(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.groupsService.joinGroup(id, userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/leave')
  leave(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.groupsService.leaveGroup(id, userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.groupsService.deleteGroup(id, userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/posts')
  createPost(@Req() req: Request, @Param('id') id: string, @Body() dto: CreatePostDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.groupsService.createPost(id, userId!, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/events')
  createEvent(@Req() req: Request, @Param('id') id: string, @Body() dto: CreateEventDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.groupsService.createEvent(id, userId!, dto);
  }
}

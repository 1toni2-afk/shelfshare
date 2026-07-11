import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { ProfileService } from './profile.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@Controller('profile')
export class ProfileController {
  constructor(private profileService: ProfileService) {}

  @UseGuards(JwtAuthGuard)
  @Get('me')
  getMyProfile(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.getMyProfile(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  updateMyProfile(@Req() req: Request, @Body() dto: UpdateProfileDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.updateMyProfile(userId!, dto);
  }

  @Get(':userId')
  getPublicProfile(@Param('userId') userId: string) {
    return this.profileService.getPublicProfile(userId);
  }
}

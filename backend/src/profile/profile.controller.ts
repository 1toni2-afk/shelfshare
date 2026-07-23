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
import { SetReadingChallengeDto } from './dto/set-reading-challenge.dto';
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

  // Înainte de ':userId', altfel ar fi interpretat ca id de utilizator.
  @Get('leaderboard/cities')
  getCityLeaderboard() {
    return this.profileService.getCityLeaderboard();
  }

  @Get('leaderboard/national')
  getNationalLeaderboard() {
    return this.profileService.getNationalLeaderboard();
  }

  @Get('leaderboard/top-readers')
  getTopReaders() {
    return this.profileService.getTopReaders();
  }

  @UseGuards(JwtAuthGuard)
  @Get('monthly-challenges')
  getMonthlyChallenges(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.getMonthlyChallenges(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get('reading-challenge')
  getReadingChallenge(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.getReadingChallenge(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Patch('reading-challenge')
  setReadingChallenge(@Req() req: Request, @Body() dto: SetReadingChallengeDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.setReadingChallengeGoal(userId!, dto.goal ?? null);
  }

  @UseGuards(JwtAuthGuard)
  @Get('activity-feed')
  getActivityFeed(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.getActivityFeed(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get('seller-analytics')
  getSellerAnalytics(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.getSellerAnalytics(userId!);
  }

  @Get(':userId')
  getPublicProfile(@Param('userId') userId: string) {
    return this.profileService.getPublicProfile(userId);
  }
}

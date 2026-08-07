import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { ProfileService } from './profile.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SetReadingChallengeDto } from './dto/set-reading-challenge.dto';
import { ReadingSurveyDto } from './dto/reading-survey.dto';
import { BOOK_GENRES } from '../common/constants/book-genres';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_PHOTO_SIZE_BYTES = 8 * 1024 * 1024;

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

  /** Lista de genuri propusă în chestionar - ca UI-ul să n-o dubleze local. */
  @Get('reading-survey/genres')
  getSurveyGenres() {
    return { genres: BOOK_GENRES };
  }

  @UseGuards(JwtAuthGuard)
  @Put('me/reading-survey')
  saveReadingSurvey(@Req() req: Request, @Body() dto: ReadingSurveyDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.saveReadingSurvey(userId!, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('me/photo')
  @UseInterceptors(
    FileInterceptor('photo', { limits: { fileSize: MAX_PHOTO_SIZE_BYTES } }),
  )
  uploadPhoto(@Req() req: Request, @UploadedFile() file: Express.Multer.File) {
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
    return this.profileService.setProfilePhoto(userId!, file.buffer);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me/photo')
  removePhoto(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.removeProfilePhoto(userId!);
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
  setReadingChallenge(
    @Req() req: Request,
    @Body() dto: SetReadingChallengeDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.setReadingChallengeGoal(
      userId!,
      dto.goal ?? null,
    );
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

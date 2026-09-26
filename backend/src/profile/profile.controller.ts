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
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { ProfileService } from './profile.service';
import { FeedSocialService } from './feed-social.service';
import { FeedCommentDto } from './dto/feed-comment.dto';
import { ReportPostDto } from '../groups/dto/report-post.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SetReadingChallengeDto } from './dto/set-reading-challenge.dto';
import { ReadingSurveyDto } from './dto/reading-survey.dto';
import { OnboardingTodoDto } from './dto/onboarding-todo.dto';
import { BOOK_GENRES } from '../common/constants/book-genres';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_PHOTO_SIZE_BYTES = 8 * 1024 * 1024;

@Controller('profile')
export class ProfileController {
  constructor(
    private profileService: ProfileService,
    private feedSocial: FeedSocialService,
  ) {}

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

  /**
   * Lista „Primii pași" de pe Home. Rutele stau înaintea lui `@Get(':userId')`
   * - altfel „me" ar fi fost citit ca id de user.
   */
  @UseGuards(JwtAuthGuard)
  @Get('me/onboarding-todo')
  getOnboardingTodo(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.getOnboardingTodo(userId!);
  }

  /** Bifează pași (cumulativ) și/sau ascunde lista. Răspunde cu starea nouă. */
  @UseGuards(JwtAuthGuard)
  @Post('me/onboarding-todo')
  saveOnboardingTodo(@Req() req: Request, @Body() dto: OnboardingTodoDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.saveOnboardingTodo(userId!, dto);
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

  /**
   * `scope` și `kind` sunt opționale: fără ele răspunsul e feedul vechi (doar
   * cei urmăriți, toate tipurile), cel pe care îl cere aplicația Flutter.
   * Câmpurile sociale adăugate de FeedSocialService sunt doar în plus.
   */
  @UseGuards(JwtAuthGuard)
  @Get('activity-feed')
  async getActivityFeed(
    @Req() req: Request,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
    @Query('scope') scope?: string,
    @Query('kind') kind?: string,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    const events = await this.profileService.getActivityFeed(
      userId!,
      limit ? parseInt(limit, 10) : undefined,
      offset ? parseInt(offset, 10) : undefined,
      {
        scope: scope === 'nearby' || scope === 'all' ? scope : 'following',
        kind: kind === 'reading' || kind === 'exchanges' ? kind : undefined,
      },
    );
    return this.feedSocial.decorate(userId!, events);
  }

  @UseGuards(JwtAuthGuard)
  @Put('activity-feed/:eventKey/like')
  likeFeedEvent(@Req() req: Request, @Param('eventKey') eventKey: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.feedSocial.like(userId!, eventKey);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('activity-feed/:eventKey/like')
  unlikeFeedEvent(@Req() req: Request, @Param('eventKey') eventKey: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.feedSocial.unlike(userId!, eventKey);
  }

  @UseGuards(JwtAuthGuard)
  @Get('activity-feed/:eventKey/comments')
  getFeedComments(@Req() req: Request, @Param('eventKey') eventKey: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.feedSocial.comments(userId!, eventKey);
  }

  @UseGuards(JwtAuthGuard)
  @Post('activity-feed/:eventKey/comments')
  addFeedComment(
    @Req() req: Request,
    @Param('eventKey') eventKey: string,
    @Body() dto: FeedCommentDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.feedSocial.addComment(userId!, eventKey, dto.text);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('activity-feed/comments/:commentId')
  deleteFeedComment(@Req() req: Request, @Param('commentId') commentId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.feedSocial.deleteComment(userId!, commentId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('activity-feed/comments/:commentId/report')
  reportFeedComment(
    @Req() req: Request,
    @Param('commentId') commentId: string,
    @Body() dto: ReportPostDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.feedSocial.reportComment(userId!, commentId, dto.reason, dto.details);
  }

  @UseGuards(JwtAuthGuard)
  @Get('seller-analytics')
  getSellerAnalytics(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.profileService.getSellerAnalytics(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':userId/compatibility')
  getCompatibility(@Req() req: Request, @Param('userId') userId: string) {
    const { userId: viewerId } = req.user as AuthenticatedUser;
    return this.profileService.getCompatibility(viewerId!, userId);
  }

  @Get(':userId')
  getPublicProfile(@Param('userId') userId: string) {
    return this.profileService.getPublicProfile(userId);
  }
}

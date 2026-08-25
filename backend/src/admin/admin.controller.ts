import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import type { Request } from 'express';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from './guards/admin.guard';
import { AdminAuditInterceptor } from './admin-audit.interceptor';
import { SetFeatureFlagsDto } from './dto/set-feature-flags.dto';
import { SetListingScoreOverrideDto } from './dto/set-listing-score-override.dto';
import { UpdateReportStatusDto } from './dto/update-report-status.dto';
import { FEATURE_FLAG_KEYS } from '../common/constants/feature-flags';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard, AdminGuard)
@UseInterceptors(AdminAuditInterceptor)
@Controller('admin')
export class AdminController {
  constructor(private adminService: AdminService) {}

  @Get('stats')
  getStats() {
    return this.adminService.getStats();
  }

  @Get('stats/marketplace')
  getMarketplaceStats() {
    return this.adminService.getMarketplaceStats();
  }

  @Get('stats/active-zones')
  getActiveZones() {
    return this.adminService.getActiveZones();
  }

  @Get('stats/security')
  getSecurityStats() {
    return this.adminService.getSecurityStats();
  }

  @Get('stats/history')
  getStatsHistory(@Query('days') days?: string) {
    return this.adminService.getStatsHistory(days ? parseInt(days, 10) : undefined);
  }

  @Get('stats/conversion-funnel')
  getConversionFunnel() {
    return this.adminService.getConversionFunnel();
  }

  @Get('users')
  getUsers(@Query('limit') limit?: string, @Query('offset') offset?: string) {
    return this.adminService.getUsers(
      limit ? parseInt(limit, 10) : undefined,
      offset ? parseInt(offset, 10) : undefined,
    );
  }

  @Get('users/search')
  searchUsers(@Query('q') q?: string) {
    return this.adminService.searchUsers(q ?? '');
  }

  @Get('feature-flags')
  getFeatureFlagKeys() {
    return { keys: FEATURE_FLAG_KEYS };
  }

  @Get('users/:id/feature-flags')
  getUserFeatureFlags(@Param('id') id: string) {
    return this.adminService.getUserFeatureFlags(id);
  }

  @Put('users/:id/feature-flags')
  setUserFeatureFlags(
    @Param('id') id: string,
    @Body() dto: SetFeatureFlagsDto,
  ) {
    return this.adminService.setUserFeatureFlags(id, dto.flags);
  }

  @Post('users/:id/ban')
  banUser(@Param('id') id: string) {
    return this.adminService.banUser(id);
  }

  @Post('users/:id/unban')
  unbanUser(@Param('id') id: string) {
    return this.adminService.unbanUser(id);
  }

  @Post('users/:id/toggle-premium')
  togglePremium(@Param('id') id: string) {
    return this.adminService.togglePremium(id);
  }

  @Post('users/:id/toggle-supporter')
  toggleSupporter(@Param('id') id: string) {
    return this.adminService.toggleSupporter(id);
  }

  @Delete('users/:id')
  deleteUser(@Param('id') id: string) {
    return this.adminService.deleteUser(id);
  }

  @Delete('books/:id')
  deleteBook(@Param('id') id: string) {
    return this.adminService.deleteBook(id);
  }

  @Delete('user-books/:id')
  deleteUserBook(@Param('id') id: string) {
    return this.adminService.deleteUserBook(id);
  }

  @Get('listings/:id/score')
  getListingScore(@Param('id') id: string) {
    return this.adminService.getListingScore(id);
  }

  @Put('listings/:id/score-override')
  setListingScoreOverride(
    @Param('id') id: string,
    @Body() dto: SetListingScoreOverrideDto,
  ) {
    return this.adminService.setListingScoreOverride(id, dto.score ?? null);
  }

  @Get('reports/inactive-listings')
  getInactiveListingsReport() {
    return this.adminService.getInactiveListingsReport();
  }

  @Get('reports/users')
  getUserReports() {
    return this.adminService.getUserReports();
  }

  @Put('reports/:id/status')
  updateReportStatus(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: UpdateReportStatusDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.adminService.updateReportStatus(
      id,
      userId!,
      dto.status,
      dto.resolutionNote,
    );
  }

  @Delete('group-posts/:id')
  deleteGroupPost(@Param('id') id: string) {
    return this.adminService.deleteGroupPost(id);
  }

  @Delete('reviews/:id')
  deleteReview(@Param('id') id: string) {
    return this.adminService.deleteReview(id);
  }

  @Get('feedback')
  getFeedback() {
    return this.adminService.getFeedback();
  }

  @Get('support-requests')
  getSupportRequests() {
    return this.adminService.getSupportRequests();
  }
}

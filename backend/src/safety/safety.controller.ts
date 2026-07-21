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
import { SafetyService } from './safety.service';
import { ReportUserDto } from './dto/report-user.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('users/:id')
export class SafetyController {
  constructor(private safetyService: SafetyService) {}

  @Get('block')
  getBlockStatus(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.safetyService.getBlockStatus(userId!, id);
  }

  @Post('block')
  block(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.safetyService.blockUser(userId!, id);
  }

  @Delete('block')
  unblock(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.safetyService.unblockUser(userId!, id);
  }

  @Post('report')
  report(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: ReportUserDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.safetyService.reportUser(userId!, id, dto);
  }
}

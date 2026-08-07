import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';
import { AccountDeletionService } from './account-deletion.service';

@Controller('account')
@UseGuards(JwtAuthGuard)
export class AccountDeletionController {
  constructor(private accountDeletion: AccountDeletionService) {}

  /// Programează ștergerea contului. Endpoint-ul e sub /account (nu /profile)
  /// ca să fie ușor de găsit pentru review-ul Google Play din URL-ul din DPP.
  @Post('delete-request')
  @HttpCode(HttpStatus.OK)
  request(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.accountDeletion.requestDeletion(userId!);
  }

  @Delete('delete-request')
  @HttpCode(HttpStatus.NO_CONTENT)
  async cancel(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    await this.accountDeletion.cancelDeletion(userId!);
  }

  /// GDPR "descarcă-ți datele" - export JSON al datelor proprii.
  @Throttle({ default: { limit: 5, ttl: 3_600_000 } })
  @Get('export-data')
  exportData(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.accountDeletion.exportMyData(userId!);
  }
}

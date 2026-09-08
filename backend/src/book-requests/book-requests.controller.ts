import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { BookRequestStatus } from '@prisma/client';
import { BookRequestsService } from './book-requests.service';
import { CreateBookRequestDto } from './dto/create-book-request.dto';
import { ResolveBookRequestDto } from './dto/resolve-book-request.dto';
import { WorkerTokenGuard } from './guards/worker-token.guard';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from '../admin/guards/admin.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@Controller('book-requests')
export class BookRequestsController {
  constructor(private bookRequests: BookRequestsService) {}

  /**
   * Coada de noapte pentru scraperele de magazine. Stă ÎNAINTEA rutei
   * `:id` de mai jos doar din obișnuință - „worker" n-ar fi confundat cu un
   * uuid, dar ordinea explicită scutește de surprize la refactor.
   */
  @UseGuards(WorkerTokenGuard)
  @Get('worker/queue')
  getQueue(@Query('limit') limit?: string) {
    const parsed = limit ? parseInt(limit, 10) : NaN;
    return this.bookRequests.queue(
      Number.isFinite(parsed) ? Math.min(Math.max(parsed, 1), 200) : undefined,
    );
  }

  /** Rezultatul căutării unui scraper: cartea găsită, sau „n-am găsit". */
  @UseGuards(WorkerTokenGuard)
  @Post('worker/resolve')
  resolveFromWorker(@Body() dto: ResolveBookRequestDto) {
    return this.bookRequests.resolveFromWorker(dto);
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin')
  listForAdmin(
    @Query('status') status?: string,
    @Query('limit') limit?: string,
  ) {
    const parsedLimit = limit ? parseInt(limit, 10) : NaN;
    const parsedStatus =
      status && status in BookRequestStatus
        ? (status as BookRequestStatus)
        : undefined;
    return this.bookRequests.listForAdmin(
      parsedStatus,
      Number.isFinite(parsedLimit) ? parsedLimit : undefined,
    );
  }

  /**
   * Formularul propriu-zis. Throttle mai strict decât cel implicit: fiecare
   * cerere devine muncă de noapte către magazine externe, deci nu are de ce
   * să poată fi trimisă în rafală.
   */
  @UseGuards(JwtAuthGuard)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post()
  create(@Req() req: Request, @Body() dto: CreateBookRequestDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookRequests.create(userId!, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('mine')
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookRequests.getMine(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  cancel(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookRequests.cancel(userId!, id);
  }
}

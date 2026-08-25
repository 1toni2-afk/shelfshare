import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Req,
  StreamableFile,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { ExchangesService } from './exchanges.service';

const MAX_CONDITION_PHOTO_SIZE_BYTES = 8 * 1024 * 1024;
import { CreateExchangeRequestDto } from './dto/create-exchange-request.dto';
import { RateExchangeDto } from './dto/rate-exchange.dto';
import { SetMeetingDto } from './dto/set-meeting.dto';
import { CancelExchangeDto } from './dto/cancel-exchange.dto';
import { ShareContactDto } from './dto/share-contact.dto';
import { DoneExchangeDto } from './dto/done-exchange.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('exchanges')
export class ExchangesController {
  constructor(private exchangesService: ExchangesService) {}

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post()
  create(@Req() req: Request, @Body() dto: CreateExchangeRequestDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.createRequest(userId!, dto);
  }

  @Get('sent')
  getSent(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.getSentRequests(userId!);
  }

  @Get('received')
  getReceived(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.getReceivedRequests(userId!);
  }

  @Get(':id')
  getOne(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.getRequest(id, userId!);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  accept(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.accept(id, userId!);
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  reject(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.reject(id, userId!);
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: CancelExchangeDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.cancel(id, userId!, dto);
  }

  @Post(':id/postpone')
  @HttpCode(HttpStatus.OK)
  postpone(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.postpone(id, userId!);
  }

  @Post(':id/done')
  @HttpCode(HttpStatus.OK)
  markDone(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: DoneExchangeDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.markDone(id, userId!, dto);
  }

  @Post(':id/done/dispute')
  @HttpCode(HttpStatus.OK)
  disputeDone(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.disputeDone(id, userId!);
  }

  @Post(':id/contact')
  @HttpCode(HttpStatus.OK)
  shareContact(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: ShareContactDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.shareContact(id, userId!, dto);
  }

  @Post(':id/safety-ack')
  @HttpCode(HttpStatus.OK)
  acknowledgeSafety(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.acknowledgeSafety(id, userId!);
  }

  @Post(':id/condition-photos')
  @UseInterceptors(
    FileInterceptor('photo', { limits: { fileSize: MAX_CONDITION_PHOTO_SIZE_BYTES } }),
  )
  addConditionPhoto(
    @Req() req: Request,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('Nicio poză primită');
    }
    if (file.size > MAX_CONDITION_PHOTO_SIZE_BYTES) {
      throw new BadRequestException('Poza este prea mare (maxim 8MB)');
    }
    if (!file.mimetype.startsWith('image/')) {
      throw new BadRequestException('Fișierul trebuie să fie o imagine');
    }

    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.addConditionPhoto(id, userId!, file.buffer);
  }

  @Throttle({ default: { limit: 20, ttl: 3_600_000 } })
  @Post(':id/rate')
  @HttpCode(HttpStatus.OK)
  rate(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: RateExchangeDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.rate(id, userId!, dto);
  }

  @Patch(':id/meeting')
  proposeMeeting(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: SetMeetingDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.proposeMeeting(id, userId!, dto);
  }

  @Post(':id/meeting/accept')
  @HttpCode(HttpStatus.OK)
  acceptMeeting(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.acceptMeeting(id, userId!);
  }

  @Post(':id/meeting/decline')
  @HttpCode(HttpStatus.OK)
  declineMeeting(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.declineMeeting(id, userId!);
  }

  @Get(':id/calendar.ics')
  @Header('Content-Type', 'text/calendar; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="schimb-shelfshare.ics"')
  async getCalendar(
    @Req() req: Request,
    @Param('id') id: string,
  ): Promise<StreamableFile> {
    const { userId } = req.user as AuthenticatedUser;
    const ics = await this.exchangesService.generateIcs(id, userId!);
    return new StreamableFile(Buffer.from(ics, 'utf-8'));
  }
}

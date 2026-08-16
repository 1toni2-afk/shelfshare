import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { CounterOfferDto } from './dto/counter-offer.dto';
import { SetMeetingDto } from '../exchanges/dto/set-meeting.dto';
import { CancelExchangeDto } from '../exchanges/dto/cancel-exchange.dto';
import { ShareContactDto } from '../exchanges/dto/share-contact.dto';
import { DoneExchangeDto } from '../exchanges/dto/done-exchange.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller()
export class OffersController {
  constructor(private offersService: OffersService) {}

  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @Post('books/:userBookId/offers')
  create(
    @Req() req: Request,
    @Param('userBookId') userBookId: string,
    @Body() dto: CreateOfferDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.createOffer(userId!, userBookId, dto);
  }

  @Get('offers/sent')
  getSent(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.getSentOffers(userId!);
  }

  @Get('offers/received')
  getReceived(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.getReceivedOffers(userId!);
  }

  @Get('offers/:id')
  getOne(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.getOne(id, userId!);
  }

  @Post('offers/:id/accept')
  @HttpCode(HttpStatus.OK)
  accept(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.accept(id, userId!);
  }

  @Post('offers/:id/reject')
  @HttpCode(HttpStatus.OK)
  reject(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.reject(id, userId!);
  }

  @Post('offers/:id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: CancelExchangeDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.cancel(id, userId!, dto);
  }

  @Post('offers/:id/postpone')
  @HttpCode(HttpStatus.OK)
  postpone(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.postpone(id, userId!);
  }

  @Post('offers/:id/done')
  @HttpCode(HttpStatus.OK)
  markDone(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: DoneExchangeDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.markDone(id, userId!, dto);
  }

  @Post('offers/:id/done/dispute')
  @HttpCode(HttpStatus.OK)
  disputeDone(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.disputeDone(id, userId!);
  }

  @Post('offers/:id/contact')
  @HttpCode(HttpStatus.OK)
  shareContact(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: ShareContactDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.shareContact(id, userId!, dto);
  }

  @Post('offers/:id/safety-ack')
  @HttpCode(HttpStatus.OK)
  acknowledgeSafety(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.acknowledgeSafety(id, userId!);
  }

  @Post('offers/:id/meeting')
  @HttpCode(HttpStatus.OK)
  proposeMeeting(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: SetMeetingDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.proposeMeeting(id, userId!, dto);
  }

  @Post('offers/:id/meeting/accept')
  @HttpCode(HttpStatus.OK)
  acceptMeeting(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.acceptMeeting(id, userId!);
  }

  @Post('offers/:id/meeting/decline')
  @HttpCode(HttpStatus.OK)
  declineMeeting(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.declineMeeting(id, userId!);
  }

  @Get('offers/:id/calendar.ics')
  @Header('Content-Type', 'text/calendar; charset=utf-8')
  @Header('Content-Disposition', 'attachment; filename="vanzare-shelfshare.ics"')
  async getCalendar(
    @Req() req: Request,
    @Param('id') id: string,
  ): Promise<StreamableFile> {
    const { userId } = req.user as AuthenticatedUser;
    const ics = await this.offersService.generateIcs(id, userId!);
    return new StreamableFile(Buffer.from(ics, 'utf-8'));
  }

  /** Contra-ofertă (Batch 11). Oricare parte poate propune preț nou. */
  @Post('offers/:id/counter')
  @HttpCode(HttpStatus.CREATED)
  counter(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: CounterOfferDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.counter(id, userId!, dto);
  }
}

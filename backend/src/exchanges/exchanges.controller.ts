import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { ExchangesService } from './exchanges.service';
import { CreateExchangeRequestDto } from './dto/create-exchange-request.dto';
import { RateExchangeDto } from './dto/rate-exchange.dto';
import { SetMeetingDto } from './dto/set-meeting.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('exchanges')
export class ExchangesController {
  constructor(private exchangesService: ExchangesService) {}

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
  cancel(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.cancel(id, userId!);
  }

  @Post(':id/complete')
  @HttpCode(HttpStatus.OK)
  complete(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.complete(id, userId!);
  }

  @Post(':id/rate')
  @HttpCode(HttpStatus.OK)
  rate(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: RateExchangeDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.rate(id, userId!, dto.value, dto.comment);
  }

  @Patch(':id/meeting')
  setMeeting(
    @Req() req: Request,
    @Param('id') id: string,
    @Body() dto: SetMeetingDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.exchangesService.setMeeting(id, userId!, new Date(dto.meetingAt));
  }

  @Get(':id/ics')
  async getIcs(
    @Req() req: Request,
    @Param('id') id: string,
    @Res() res: Response,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    const content = await this.exchangesService.getIcsContent(id, userId!);
    res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="schimb-${id}.ics"`);
    res.send(content);
  }
}

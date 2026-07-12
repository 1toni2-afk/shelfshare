import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { ExchangesService } from './exchanges.service';
import { CreateExchangeRequestDto } from './dto/create-exchange-request.dto';
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
}

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
import { OffersService } from './offers.service';
import { CreateOfferDto } from './dto/create-offer.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller()
export class OffersController {
  constructor(private offersService: OffersService) {}

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
  cancel(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.offersService.cancel(id, userId!);
  }
}

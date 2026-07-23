import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { AuctionsService } from './auctions.service';
import { CreateAuctionDto } from './dto/create-auction.dto';
import { PlaceBidDto } from './dto/place-bid.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@Controller()
export class AuctionsController {
  constructor(private auctionsService: AuctionsService) {}

  @UseGuards(JwtAuthGuard)
  @Post('books/:userBookId/auctions')
  create(
    @Req() req: Request,
    @Param('userBookId') userBookId: string,
    @Body() dto: CreateAuctionDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.auctionsService.createAuction(userId!, userBookId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('auctions/my-bids')
  getMyBids(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.auctionsService.getMyBids(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get('auctions/my-watches')
  getMyWatches(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.auctionsService.getMyWatches(userId!);
  }

  @UseGuards(OptionalJwtAuthGuard)
  @Get('auctions/:id')
  getOne(@Req() req: Request, @Param('id') id: string) {
    const user = req.user as AuthenticatedUser | undefined;
    return this.auctionsService.getAuction(id, user?.userId);
  }

  @UseGuards(JwtAuthGuard)
  @Post('auctions/:id/bids')
  placeBid(@Req() req: Request, @Param('id') id: string, @Body() dto: PlaceBidDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.auctionsService.placeBid(userId!, id, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('auctions/:id/buy-now')
  @HttpCode(HttpStatus.OK)
  buyNow(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.auctionsService.buyNow(userId!, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('auctions/:id/watch')
  @HttpCode(HttpStatus.OK)
  watch(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.auctionsService.watch(userId!, id);
  }

  @UseGuards(JwtAuthGuard)
  @Delete('auctions/:id/watch')
  unwatch(@Req() req: Request, @Param('id') id: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.auctionsService.unwatch(userId!, id);
  }
}

import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Body,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { WishlistService } from './wishlist.service';
import { AddToWishlistDto } from './dto/add-to-wishlist.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('wishlist')
export class WishlistController {
  constructor(private wishlistService: WishlistService) {}

  @Post()
  add(@Req() req: Request, @Body() dto: AddToWishlistDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.wishlistService.add(userId!, dto.bookId, dto.userBookId);
  }

  @Get()
  getMine(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.wishlistService.getMine(userId!);
  }

  /// Declarată ÎNAINTE de `:bookId`, altfel „listing" ar fi citit ca bookId.
  /// Scoate favoritul unui singur anunț (inima de pe card/detaliu), spre
  /// deosebire de ruta de mai jos care scoate titlul întreg.
  @Delete('listing/:userBookId')
  removeListing(@Req() req: Request, @Param('userBookId') userBookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.wishlistService.removeListing(userId!, userBookId);
  }

  @Delete(':bookId')
  remove(@Req() req: Request, @Param('bookId') bookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.wishlistService.remove(userId!, bookId);
  }
}

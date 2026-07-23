import { Body, Controller, Delete, Get, Param, Put, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { BookshelfService } from './bookshelf.service';
import { SetBookshelfStatusDto } from './dto/set-bookshelf-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

@UseGuards(JwtAuthGuard)
@Controller('bookshelf')
export class BookshelfController {
  constructor(private bookshelfService: BookshelfService) {}

  // Înainte de ':bookId', altfel 'me' ar fi interpretat ca id de carte.
  @Get('me')
  getMyShelf(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookshelfService.getMyShelf(userId!);
  }

  @Get('me/:bookId')
  getStatusForBook(@Req() req: Request, @Param('bookId') bookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookshelfService.getStatusForBook(userId!, bookId);
  }

  @Put(':bookId')
  setStatus(
    @Req() req: Request,
    @Param('bookId') bookId: string,
    @Body() dto: SetBookshelfStatusDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookshelfService.setStatus(userId!, bookId, dto.status);
  }

  @Delete(':bookId')
  remove(@Req() req: Request, @Param('bookId') bookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookshelfService.removeFromShelf(userId!, bookId);
  }
}

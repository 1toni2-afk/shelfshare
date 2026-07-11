import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { BooksService } from './books.service';
import { AddBookDto } from './dto/add-book.dto';
import { UpdateUserBookDto } from './dto/update-user-book.dto';
import { SearchBookDto } from './dto/search-book.dto';
import { SearchLibraryDto } from './dto/search-library.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_PHOTO_SIZE_BYTES = 8 * 1024 * 1024; // 8MB - suficient pentru poze de telefon, sharp le comprimă oricum după

@Controller('books')
export class BooksController {
  constructor(private booksService: BooksService) {}

  @Get('search')
  searchExternal(@Query() query: SearchBookDto) {
    return this.booksService.searchExternal(query.q);
  }

  // Căutare printre cărțile deja oferite de utilizatori, cu filtre.
  // Plasată înainte de :userBookId, altfel "browse" ar fi interpretat ca ID.
  @Get('browse')
  searchLibrary(@Query() filters: SearchLibraryDto) {
    return this.booksService.searchLibrary(filters);
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  addToLibrary(@Req() req: Request, @Body() dto: AddBookDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.addToLibrary(userId!, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('my-library')
  getMyLibrary(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getMyLibrary(userId!);
  }

  @Get(':userBookId')
  getUserBook(@Param('userBookId') userBookId: string) {
    return this.booksService.getUserBook(userBookId);
  }

  @UseGuards(JwtAuthGuard)
  @Patch(':userBookId')
  updateUserBook(
    @Req() req: Request,
    @Param('userBookId') userBookId: string,
    @Body() dto: UpdateUserBookDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.updateUserBook(userId!, userBookId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':userBookId')
  deleteUserBook(@Req() req: Request, @Param('userBookId') userBookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.deleteUserBook(userId!, userBookId);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':userBookId/photos')
  @UseInterceptors(FileInterceptor('photo'))
  addPhoto(
    @Req() req: Request,
    @Param('userBookId') userBookId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('Nicio poză primită');
    }
    if (file.size > MAX_PHOTO_SIZE_BYTES) {
      throw new BadRequestException('Poza este prea mare (maxim 8MB)');
    }
    if (!file.mimetype.startsWith('image/')) {
      throw new BadRequestException('Fișierul trebuie să fie o imagine');
    }

    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.addPhoto(userId!, userBookId, file.buffer);
  }
}

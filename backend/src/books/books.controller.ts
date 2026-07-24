import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
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
import { BulkAddBooksDto } from './dto/bulk-add-books.dto';
import { UpdateUserBookDto } from './dto/update-user-book.dto';
import { SearchBookDto } from './dto/search-book.dto';
import { SearchLibraryDto } from './dto/search-library.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { OptionalJwtAuthGuard } from '../auth/guards/optional-jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_PHOTO_SIZE_BYTES = 8 * 1024 * 1024; // 8MB - suficient pentru poze de telefon, sharp le comprimă oricum după
const MAX_IMPORT_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10MB - suficient pentru câteva sute de rânduri CSV

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

  // Tot înainte de :userBookId, din același motiv ca 'browse'.
  @Get('genres')
  getGenres(@Query('query') query?: string) {
    return this.booksService.getGenres(query);
  }

  // Sugestii de auto-fill pentru filtrele Author/Language - tot înainte de
  // :userBookId, din același motiv ca 'browse'/'genres'.
  @Get('authors')
  getAuthors(@Query('query') query?: string) {
    return this.booksService.getAuthors(query);
  }

  @Get('languages')
  getLanguages(@Query('query') query?: string) {
    return this.booksService.getLanguages(query);
  }

  // Statistici globale - tot înainte de :userBookId, din același motiv.
  @Get('most-shared')
  getMostSharedBooks() {
    return this.booksService.getMostSharedBooks();
  }

  @Get('trending')
  getTrendingBooks() {
    return this.booksService.getTrendingBooks();
  }

  @Get('popular-authors')
  getMostPopularAuthors() {
    return this.booksService.getMostPopularAuthors();
  }

  // Tot înainte de :userBookId, din același motiv ca 'browse'.
  @Get('map-cities')
  getMapCities() {
    return this.booksService.getMapCities();
  }

  @Get('popular-searches')
  getPopularSearches() {
    return this.booksService.getPopularSearches();
  }

  @Get('nearby-today')
  getNearbyToday(@Query('city') city: string) {
    return this.booksService.getNearbyToday(city);
  }

  @Get('hidden-gems')
  getHiddenGems() {
    return this.booksService.getHiddenGems();
  }

  @UseGuards(JwtAuthGuard)
  @Get('recommended')
  getRecommendedForYou(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getRecommendedForYou(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get('complete-your-collection')
  getCompleteYourCollection(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getCompleteYourCollection(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get('smart-matches')
  getSmartMatches(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getSmartMatches(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get('similar-taste-users')
  getSimilarTasteUsers(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getSimilarTasteUsers(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  addToLibrary(@Req() req: Request, @Body() dto: AddBookDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.addToLibrary(userId!, dto);
  }

  // Tot înainte de :userBookId, din același motiv ca 'browse'.
  @UseGuards(JwtAuthGuard)
  @Get('lookup-isbn')
  lookupIsbnPreview(@Query('isbn') isbn: string) {
    return this.booksService.lookupIsbnPreview(isbn);
  }

  @UseGuards(JwtAuthGuard)
  @Post('bulk')
  bulkAddToLibrary(@Req() req: Request, @Body() dto: BulkAddBooksDto) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.bulkAddToLibrary(userId!, dto.isbns, dto.condition, dto.language);
  }

  @UseGuards(JwtAuthGuard)
  @Post('import-listings')
  @UseInterceptors(FileInterceptor('file'))
  importListingsCsv(@Req() req: Request, @UploadedFile() file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('Niciun fișier primit');
    }
    if (file.size > MAX_IMPORT_FILE_SIZE_BYTES) {
      throw new BadRequestException('Fișierul este prea mare (maxim 10MB)');
    }
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.importListingsCsv(userId!, file.buffer);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':userBookId/relist')
  relistBook(
    @Req() req: Request,
    @Param('userBookId') userBookId: string,
    @Body() dto: AddBookDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.relistBook(userId!, userBookId, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('my-library')
  getMyLibrary(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getMyLibrary(userId!);
  }

  @UseGuards(OptionalJwtAuthGuard)
  @Get(':userBookId')
  getUserBook(@Req() req: Request, @Param('userBookId') userBookId: string) {
    const user = req.user as AuthenticatedUser | undefined;
    return this.booksService.viewUserBook(userBookId, user?.userId);
  }

  @Get(':userBookId/views')
  getViewStats(@Param('userBookId') userBookId: string) {
    return this.booksService.getViewStats(userBookId);
  }

  // Distinct de getUserBook - nu incrementează viewCount. Folosit de
  // static-server.js pentru a genera meta tag-uri (SEO/Open Graph) fără
  // să umfle statisticile de vizualizări la fiecare hit de crawler.
  @Get(':userBookId/preview')
  getPreview(@Param('userBookId') userBookId: string) {
    return this.booksService.getPreview(userBookId);
  }

  @Get(':userBookId/history')
  getListingHistory(@Param('userBookId') userBookId: string) {
    return this.booksService.getListingHistory(userBookId);
  }

  @Get(':userBookId/similar')
  getSimilarBooks(@Param('userBookId') userBookId: string) {
    return this.booksService.getSimilarBooks(userBookId);
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
  @Post(':userBookId/toggle-promoted')
  @HttpCode(HttpStatus.OK)
  togglePromoted(@Req() req: Request, @Param('userBookId') userBookId: string) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.togglePromoted(userId!, userBookId);
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

import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import type { Request, Response } from 'express';
import { BooksService } from './books.service';
import { AddBookDto } from './dto/add-book.dto';
import { BulkAddBooksDto } from './dto/bulk-add-books.dto';
import { UpdateUserBookDto } from './dto/update-user-book.dto';
import { SearchBookDto } from './dto/search-book.dto';
import { SearchLibraryDto } from './dto/search-library.dto';
import { AddPhotoUrlDto } from './dto/add-photo-url.dto';
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

  /**
   * Proxy pentru coperțile care nu trimit Access-Control-Allow-Origin (Google
   * Books) - vezi BookLookupService.fetchCoverImage. Servite de pe domeniul
   * nostru, ca randarea pe Flutter Web (CanvasKit) să nu mai depindă de CORS-ul
   * terților. Throttle mai strict decât restul - un endpoint care face fetch
   * către un URL arbitrar (chiar și cu listă albă de gazde) e o țintă bună
   * pentru abuz.
   */
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @Get('cover-proxy')
  async proxyCover(@Query('url') url: string, @Res() res: Response) {
    if (!url) throw new BadRequestException('Parametrul url lipsește');
    const image = await this.booksService.fetchCoverImage(url);
    if (!image) throw new NotFoundException('Coperta nu a putut fi încărcată');
    res.setHeader('Content-Type', image.contentType);
    res.setHeader('Cache-Control', 'public, max-age=86400');
    res.send(image.data);
  }

  /**
   * Coperte candidate pentru un titlu + autor (Batch 8). Folosite în ecranul
   * „Adaugă carte" când user tastează manual (fără să aleagă din autocomplete);
   * întoarcem un array plat de URL-uri unice de copertă, până la 4.
   */
  @Get('covers')
  async suggestCovers(
    @Query('title') title?: string,
    @Query('author') author?: string,
  ) {
    return this.booksService.suggestCovers(title, author);
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

  @Get('trending-listings')
  getTrendingListings() {
    return this.booksService.getTrendingListings();
  }

  @Get('most-wished')
  getMostWishedBooks() {
    return this.booksService.getMostWishedBooks();
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
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
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
    return this.booksService.bulkAddToLibrary(
      userId!,
      dto.isbns,
      dto.condition,
      dto.language,
    );
  }

  @UseGuards(JwtAuthGuard)
  @Post('import-listings')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_IMPORT_FILE_SIZE_BYTES },
    }),
  )
  importListingsCsv(
    @Req() req: Request,
    @UploadedFile() file: Express.Multer.File,
  ) {
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

  /// Coșul de gunoi (Milestone 10): cărțile șterse recent (< 7 zile).
  /// Rutele mai specifice trebuie declarate ÎNAINTE de `:userBookId`, altfel
  /// „deleted" / „emptied" ar fi capturate ca id de anunț.
  @UseGuards(JwtAuthGuard)
  @Get('my-library/deleted')
  getDeletedUserBooks(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getDeletedUserBooks(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Get('my-library/emptied')
  getEmptiedShelves(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.getEmptiedShelves(userId!);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':userBookId/restore')
  restoreUserBook(
    @Req() req: Request,
    @Param('userBookId') userBookId: string,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.restoreUserBook(userId!, userBookId);
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
  @UseInterceptors(
    FileInterceptor('photo', { limits: { fileSize: MAX_PHOTO_SIZE_BYTES } }),
  )
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

  @UseGuards(JwtAuthGuard)
  @Post(':userBookId/photos/from-url')
  addPhotoUrl(
    @Req() req: Request,
    @Param('userBookId') userBookId: string,
    @Body() dto: AddPhotoUrlDto,
  ) {
    const { userId } = req.user as AuthenticatedUser;
    return this.booksService.addPhotoUrl(userId!, userBookId, dto.url);
  }
}

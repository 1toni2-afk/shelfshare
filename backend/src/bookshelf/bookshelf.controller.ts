import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { BookshelfService } from './bookshelf.service';
import type { BookshelfImportSource } from './bookshelf.service';
import { SetBookshelfStatusDto } from './dto/set-bookshelf-status.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import type { AuthenticatedUser } from '../auth/types/authenticated-user';

const MAX_IMPORT_FILE_SIZE_BYTES = 10 * 1024 * 1024; // 10MB - suficient pentru câteva mii de rânduri CSV

@UseGuards(JwtAuthGuard)
@Controller('bookshelf')
export class BookshelfController {
  constructor(private bookshelfService: BookshelfService) {}

  // Înainte de ':bookId', altfel 'me'/'import' ar fi interpretate ca id de carte.
  @Get('me')
  getMyShelf(@Req() req: Request) {
    const { userId } = req.user as AuthenticatedUser;
    return this.bookshelfService.getMyShelf(userId!);
  }

  @Post('import/:source')
  @UseInterceptors(FileInterceptor('file'))
  importCsv(
    @Req() req: Request,
    @Param('source') source: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (source !== 'goodreads' && source !== 'storygraph') {
      throw new BadRequestException('Sursă de import necunoscută');
    }
    if (!file) {
      throw new BadRequestException('Niciun fișier primit');
    }
    if (file.size > MAX_IMPORT_FILE_SIZE_BYTES) {
      throw new BadRequestException('Fișierul este prea mare (maxim 10MB)');
    }

    const { userId } = req.user as AuthenticatedUser;
    return this.bookshelfService.importCsv(userId!, source as BookshelfImportSource, file.buffer);
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

import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsISBN,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { BookshelfStatus } from '@prisma/client';

/**
 * „Add to shelf" - cartea intră în raftul personal ca DEȚINUTĂ, fără să
 * creeze un anunț (UserBook). Deliberat mai sărac decât AddBookDto: aici nu
 * există stare/poze/preț/oraș, fiindcă nimeni în afară de proprietar nu vede
 * exemplarul. Metadatele de carte (titlu, autor, copertă, pagini) vin din
 * autocomplete-ul din ecranul de adăugare, la fel ca la listare.
 */
export class AddOwnedBookDto {
  @IsOptional()
  @IsISBN(undefined, { message: 'ISBN invalid' })
  isbn?: string;

  @IsString()
  @MaxLength(300)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  author?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  genre?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  publisher?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2100)
  publishedYear?: number;

  @IsOptional()
  @IsEnum(BookshelfStatus, { message: 'Status invalid' })
  status?: BookshelfStatus;

  /// Paginile ediției pe care o are userul - poate diferi de cea din catalog.
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30000)
  totalPages?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(30000)
  currentPage?: number;

  /// Alternativă la `currentPage` pentru userii care știu doar „sunt pe la
  /// jumate" - convertit în pagini pe backend, ca sursa de adevăr să rămână
  /// una singură (vezi ReadingProgress.currentPage).
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  percentRead?: number;

  @IsOptional()
  @IsBoolean()
  owned?: boolean;
}

import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

/// Metadatele găsite de un scraper de magazin pentru o cerere. Aceleași
/// câmpuri ca `ExternalBookResult`, minus ce nu are cum să vină dintr-un
/// anunț de librărie (subjects, bookId).
export class ResolvedBookDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  author?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  isbn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  coverUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  publisher?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  publishedYear?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  pageCount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  language?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  genre?: string;
}

export class ResolveBookRequestDto {
  @IsString()
  requestId: string;

  /// Care magazin a găsit-o („libris", „carturesti", „targulcartii") - ajunge
  /// în `BookRequest.resolvedSource`, ca să știm care sursă chiar produce.
  @IsString()
  @MaxLength(50)
  source: string;

  /// Lipsă = „am căutat și n-am găsit": doar incrementăm încercările.
  @IsOptional()
  @ValidateNested()
  @Type(() => ResolvedBookDto)
  book?: ResolvedBookDto;

  /// Rândul intră în catalogul verificat manual (`Book.curatedAt`), ca
  /// titlurile venite de la librăriile românești să fie preferate la căutare,
  /// exact ca cele ~1900 scrapuite deja. Implicit false.
  @IsOptional()
  @IsBoolean()
  curated?: boolean;
}

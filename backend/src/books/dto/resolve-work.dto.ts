import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Un rezultat de căutare externă (Google Books / Open Library) pe care userul
 * l-a deschis din Discovery, înainte să existe ca rând în catalog.
 *
 * Deliberat permisiv: sursele externe întorc des date incomplete sau ISBN-uri
 * care nu trec validarea strictă (`@IsISBN`), iar refuzul cererii ar face
 * pagina „despre carte" să nu se deschidă deloc pentru titluri perfect
 * valide. Singurul câmp obligatoriu e titlul, ca la orice carte din catalog.
 */
export class ResolveWorkDto {
  @IsString()
  @MaxLength(300)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  author?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  isbn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  coverUrl?: string;

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
  @IsInt()
  @Min(1)
  @Max(30000)
  pageCount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  language?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  genre?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  source?: string;
}

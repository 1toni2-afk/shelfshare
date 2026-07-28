import {
  ArrayMaxSize,
  IsArray,
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
import { BookCondition } from '@prisma/client';

/**
 * O carte nu poate porni "la vânzare" chiar la creare - fotografiile se
 * urcă printr-un apel separat, DUPĂ ce anunțul există deja, deci n-ar putea
 * niciodată trece verificarea "cel puțin o poză" din updateUserBook. Fluxul
 * corect: se creează anunțul (mereu isForSale: false), se urcă pozele, apoi
 * clientul trece explicit la vânzare prin PATCH /books/:id (updateUserBook).
 */
export class AddBookDto {
  @IsOptional()
  @IsISBN(undefined, { message: 'ISBN invalid' })
  isbn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  author?: string;

  @IsEnum(BookCondition, { message: 'Stare invalidă' })
  condition: BookCondition;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  language?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  edition?: string;

  @IsOptional()
  @IsBoolean()
  isHardcover?: boolean;

  // ---------- Metadate opționale pentru operă (Milestone 10) ----------
  // Astea populează entitatea Book (partajată) doar dacă o creăm nouă -
  // pentru cărți deja existente în catalog, câmpurile din DTO sunt ignorate,
  // ca să nu suprascriem date populate de alți useri sau de lookup extern.

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
  @IsInt()
  @Min(1)
  @Max(2100)
  editionYear?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(30000)
  pageCount?: number;

  // ---------- Câmpuri per exemplar (Milestone 10) ----------

  @IsOptional()
  @IsString()
  @MaxLength(256, { message: 'Descrierea nu poate depăși 256 de caractere' })
  description?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5, { message: 'Poți adăuga maxim 5 taguri' })
  @IsString({ each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;
}

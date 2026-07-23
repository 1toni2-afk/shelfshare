import {
  IsBoolean,
  IsEnum,
  IsISBN,
  IsOptional,
  IsString,
  MaxLength,
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
}

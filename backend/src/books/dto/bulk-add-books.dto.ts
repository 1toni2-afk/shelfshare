import { ArrayMaxSize, ArrayMinSize, IsArray, IsEnum, IsISBN, IsOptional, IsString } from 'class-validator';
import { BookCondition } from '@prisma/client';

export class BulkAddBooksDto {
  // Limitat la 50 - fiecare ISBN necunoscut local declanșează o căutare
  // externă (Open Library/Google Books), procesată secvențial ca la
  // importul CSV Goodreads/StoryGraph - suficient pentru o sesiune de
  // scanare, fără riscul unui request foarte lung.
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @IsISBN(undefined, { each: true, message: 'ISBN invalid' })
  isbns: string[];

  @IsEnum(BookCondition, { message: 'Stare invalidă' })
  condition: BookCondition;

  @IsOptional()
  @IsString()
  language?: string;
}

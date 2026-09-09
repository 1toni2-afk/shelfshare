import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsISBN,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';
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

  /// Opțional - vezi AddBookDto.condition.
  @IsOptional()
  @IsEnum(BookCondition, { message: 'Stare invalidă' })
  condition?: BookCondition;

  @IsOptional()
  @IsString()
  language?: string;

  /// Contul de magazin în numele căruia se adaugă (vezi StoreProfile).
  /// Lipsă = pe contul propriu. Ruta e rezervată super-adminilor, iar ținta
  /// trebuie să fie un magazin ACTIV - vezi StoresService.assertActiveStore.
  @IsOptional()
  @IsUUID()
  storeUserId?: string;
}

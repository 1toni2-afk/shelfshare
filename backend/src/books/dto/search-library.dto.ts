import {
  IsBooleanString,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { BookCondition } from '@prisma/client';
import { ROMANIAN_CITIES } from '../../common/constants/romanian-cities';

export class SearchLibraryDto {
  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsString()
  author?: string;

  @IsOptional()
  @IsString()
  genre?: string;

  @IsOptional()
  @IsString()
  language?: string;

  @IsOptional()
  @IsIn(ROMANIAN_CITIES, { message: 'Orașul selectat nu este valid' })
  city?: string;

  @IsOptional()
  @IsEnum(BookCondition, { message: 'Stare invalidă' })
  condition?: BookCondition;

  @IsOptional()
  @IsBooleanString()
  availableOnly?: string;

  /**
   * Tip de anunț - implicit arată swap+vânzare (comportamentul de dinainte).
   * „donation" e o vânzare la preț 0 (vezi add_book_screen.dart: nu există
   * coloană separată în DB), iar „sale" exclude explicit donațiile, altfel
   * cele două filtre s-ar suprapune.
   */
  @IsOptional()
  @IsIn(['swap', 'sale', 'auction', 'donation'])
  listingType?: 'swap' | 'sale' | 'auction' | 'donation';

  @IsOptional()
  @IsIn(['popularity', 'recent', 'oldest', 'mostViewed', 'distance'])
  sort?: 'popularity' | 'recent' | 'oldest' | 'mostViewed' | 'distance';

  /** Orașul utilizatorului care caută - folosit pentru calculul de distanță. */
  @IsOptional()
  @IsIn(ROMANIAN_CITIES, { message: 'Orașul selectat nu este valid' })
  fromCity?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2000)
  maxDistanceKm?: number;

  /**
   * Ascunde anunțurile acestui user din rezultate. Folosit de secțiunea
   * „aproape de tine" din Home, care nu are ce arăta cu propriile anunțuri.
   * Nu e un filtru de securitate (oricine poate trimite orice id) - doar
   * ascunde anunțuri deja publice, deci nu cere autentificare.
   */
  @IsOptional()
  @IsString()
  excludeUserId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 20;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number = 0;
}

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

  @IsOptional()
  @IsIn(['recent', 'mostViewed', 'distance'])
  sort?: 'recent' | 'mostViewed' | 'distance';

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

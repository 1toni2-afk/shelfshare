import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { BookCondition } from '@prisma/client';

export class UpdateUserBookDto {
  @IsOptional()
  @IsEnum(BookCondition, { message: 'Stare invalidă' })
  condition?: BookCondition;

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

  @IsOptional()
  @IsBoolean()
  availableForSwap?: boolean;

  @IsOptional()
  @IsBoolean()
  isForSale?: boolean;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(99999)
  salePrice?: number;

  @IsOptional()
  @IsBoolean()
  isNegotiable?: boolean;

  /**
   * „Sau vinde cu X lei" pentru anunțurile de tip Schimb: setat explicit la
   * listare, permite oferte în bani fără ca anunțul să devină „Vânzare"
   * (isForSale rămâne false). `null` dezactivează opțiunea.
   */
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(99999)
  swapSalePrice?: number | null;

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

  /// Setează poza principală afișată în feed/carduri (Batch 8). Poate fi
  /// una din pozele urcate (`photos[]`) sau o copertă externă. `null`
  /// resetează la fallback (prima poză, apoi coperta cărții).
  @IsOptional()
  @IsString()
  @MaxLength(500)
  mainPhotoUrl?: string | null;
}

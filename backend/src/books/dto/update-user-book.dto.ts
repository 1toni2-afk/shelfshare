import {
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
}

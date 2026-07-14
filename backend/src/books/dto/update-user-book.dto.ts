import {
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
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
}

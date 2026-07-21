import {
  IsBoolean,
  IsEnum,
  IsISBN,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { BookCondition } from '@prisma/client';

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

  @IsOptional()
  @IsBoolean()
  isForSale?: boolean;

  @ValidateIf((o: AddBookDto) => o.isForSale === true)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  @Max(99999)
  salePrice?: number;

  @IsOptional()
  @IsBoolean()
  isNegotiable?: boolean;
}

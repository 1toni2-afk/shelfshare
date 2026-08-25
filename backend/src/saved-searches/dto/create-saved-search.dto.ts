import {
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateSavedSearchDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  label: string;

  @IsOptional()
  @IsString()
  genre?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  maxPrice?: number;
}

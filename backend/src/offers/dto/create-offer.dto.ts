import { IsNumber, IsOptional, IsPositive, IsString, MaxLength } from 'class-validator';

export class CreateOfferDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}

import { IsNumber, IsPositive } from 'class-validator';

export class PlaceBidDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount: number;
}

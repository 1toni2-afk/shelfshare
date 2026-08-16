import { IsIn, IsNumber, IsPositive } from 'class-validator';

export class CreateAuctionDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  startingPrice: number;

  /** Presetate (24h/3zile/7zile) - fără durată liberă, ca să nu fie nevoie de un date-picker separat. */
  @IsIn([24, 72, 168])
  durationHours: number;
}

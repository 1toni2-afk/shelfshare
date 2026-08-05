import {
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
} from 'class-validator';

/// Contra-ofertă (Batch 11): oricare dintre părți poate propune un preț
/// alternativ pentru aceeași carte. Original devine REJECTED, iar noua
/// ofertă e postată automat ca mesaj în chat, cu rolurile buyer/owner
/// inversate ca fluxul accept/reject să funcționeze fără cazuri speciale.
export class CounterOfferDto {
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}

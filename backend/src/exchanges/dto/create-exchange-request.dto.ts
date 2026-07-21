import {
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class CreateExchangeRequestDto {
  @IsUUID()
  requestedBookId: string;

  @IsOptional()
  @IsUUID()
  offeredBookId?: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  offeredAmount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  message?: string;
}

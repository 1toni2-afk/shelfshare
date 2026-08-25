import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

// Feature backlog #17: bundle transactions - un requester poate oferi mai
// multe cărți dintr-o dată la un singur schimb. Un plafon rezonabil, ca să nu
// se transforme cererea de schimb într-un transfer în masă al bibliotecii.
const MAX_BUNDLE_BOOKS = 5;

export class CreateExchangeRequestDto {
  @IsUUID()
  requestedBookId: string;

  @IsOptional()
  @IsUUID()
  offeredBookId?: string;

  /** Cărți suplimentare oferite în același pachet, dincolo de `offeredBookId` (prima/principala carte oferită). */
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @ArrayMaxSize(MAX_BUNDLE_BOOKS)
  @IsUUID('4', { each: true })
  additionalOfferedBookIds?: string[];

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  offeredAmount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  message?: string;
}

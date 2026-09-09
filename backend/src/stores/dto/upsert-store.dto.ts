import {
  IsBoolean,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

/** Câmpurile publice ale magazinului - toate text liber, vezi StoreProfile. */
export class StoreProfileFieldsDto {
  @IsString()
  @MinLength(2, { message: 'Numele magazinului e prea scurt' })
  @MaxLength(120)
  displayName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  website?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  openingHours?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  deliveryPolicy?: string;
}

/** Transformă un cont existent în cont de magazin (sau îi rescrie datele). */
export class CreateStoreDto extends StoreProfileFieldsDto {
  @IsUUID()
  userId!: string;
}

export class UpdateStoreDto extends StoreProfileFieldsDto {
  /// Suspendarea temporară a unui magazin fără să-i ștergem datele: `false`
  /// stinge `User.isStore`, deci anunțurile nu mai sunt tratate ca de magazin,
  /// dar profilul rămâne ca să poată fi repornit dintr-un click.
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

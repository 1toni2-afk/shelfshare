import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { ROMANIAN_CITIES } from '../../common/constants/romanian-cities';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2, { message: 'Numele trebuie să aibă minim 2 caractere' })
  @MaxLength(50, { message: 'Numele poate avea maxim 50 de caractere' })
  name?: string;

  @IsOptional()
  @Matches(/^[a-zA-Z0-9_]{3,20}$/, {
    message:
      'Username-ul trebuie să aibă 3-20 caractere: litere, cifre sau underscore',
  })
  username?: string;

  @IsOptional()
  @IsBoolean()
  nameVisible?: boolean;

  @IsOptional()
  @IsIn(ROMANIAN_CITIES, { message: 'Orașul selectat nu este valid' })
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500, { message: 'Bio poate avea maxim 500 de caractere' })
  bio?: string;

  @IsOptional()
  @IsBoolean()
  showAcquisitionHistory?: boolean;
}

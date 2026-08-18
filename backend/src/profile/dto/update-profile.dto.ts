import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { ROMANIAN_CITIES } from '../../common/constants/romanian-cities';
import { capitalizeName } from '../../common/utils/capitalize-name';

export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2, { message: 'Numele trebuie să aibă minim 2 caractere' })
  @MaxLength(50, { message: 'Numele poate avea maxim 50 de caractere' })
  // Normalizarea stă pe DTO, nu în service: se aplică pe orice cale care ajunge
  // la actualizarea profilului, inclusiv pe cele adăugate ulterior.
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? capitalizeName(value) : value,
  )
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
  // 20 de caractere - „About me" e o singură linie sub numele din profil, nu un
  // paragraf. Ținut sincronizat cu kBioMaxLength din edit_profile_screen.dart.
  @MaxLength(20, { message: 'Despre mine poate avea maxim 20 de caractere' })
  bio?: string;

  @IsOptional()
  @IsBoolean()
  showAcquisitionHistory?: boolean;

  // Preferință per-admin pentru badge-ul de scor pe cardurile de carte - vezi
  // User.showAllListingScores. Fără efect pentru non-admini (endpointul de
  // scoruri întoarce mereu {} pentru ei, indiferent de acest flag).
  @IsOptional()
  @IsBoolean()
  showAllListingScores?: boolean;

  // Ziua de naștere, fără an - vezi comentariul de pe User.birthdayDay. Nu
  // validăm aici combinația zi/lună (ex. 31 februarie): singurul efect al unei
  // date imposibile e că mesajul „La mulți ani" nu apare niciodată.
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  birthdayDay?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(12)
  birthdayMonth?: number;

  // Lista de limbi în care userul citește (Milestone 18). Doar informativ pe
  // profil, nu are impact funcțional. Fără validare pe conținut (o listă
  // liberă), doar limita ca să nu ajungem cu 200 de intrări.
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsString({ each: true })
  languages?: string[];
}

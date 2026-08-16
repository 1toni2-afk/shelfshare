import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsString,
  ValidateNested,
} from 'class-validator';
import { FEATURE_FLAG_KEYS } from '../../common/constants/feature-flags';

export class FeatureFlagValueDto {
  @IsString()
  @IsIn(FEATURE_FLAG_KEYS as unknown as string[])
  key: string;

  @IsBoolean()
  enabled: boolean;
}

/**
 * Lista completă de checkbox-uri trimisă la „Aplică" - un PUT, nu un toggle
 * per funcție, ca ecranul de admin să nu poată ajunge în stări parțiale dacă
 * pică un request din mijloc.
 */
export class SetFeatureFlagsDto {
  @IsArray()
  @ArrayMaxSize(FEATURE_FLAG_KEYS.length)
  @ValidateNested({ each: true })
  @Type(() => FeatureFlagValueDto)
  flags: FeatureFlagValueDto[];
}

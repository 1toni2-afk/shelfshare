import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsString,
  ValidateNested,
} from 'class-validator';
import { NOTIFICATION_TYPES } from '../notification-types';

export class NotificationPreferenceDto {
  @IsString()
  @IsIn(NOTIFICATION_TYPES as unknown as string[])
  type: string;

  @IsBoolean()
  enabled: boolean;
}

/**
 * Un PUT parțial, nu întreaga hartă: ecranul de setări comută o categorie
 * odată (ex. „Urmăriri" = două tipuri), iar restul preferințelor rămân
 * neatinse - două tab-uri deschise nu se suprascriu reciproc.
 */
export class SetNotificationPreferencesDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(NOTIFICATION_TYPES.length)
  @ValidateNested({ each: true })
  @Type(() => NotificationPreferenceDto)
  preferences: NotificationPreferenceDto[];
}

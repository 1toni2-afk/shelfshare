import { ArrayMaxSize, IsArray, IsIn, IsString, MinLength } from 'class-validator';
import { ADMIN_PERMISSION_KEYS } from '../constants/admin-permissions';

export class UpsertCustomRoleDto {
  @IsString()
  @MinLength(2)
  label: string;

  @IsArray()
  @ArrayMaxSize(ADMIN_PERMISSION_KEYS.length)
  @IsIn(ADMIN_PERMISSION_KEYS as unknown as string[], { each: true })
  permissions: string[];
}

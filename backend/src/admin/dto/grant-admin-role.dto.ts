import { IsString } from 'class-validator';

/**
 * Rolurile predefinite sunt seed-ate ca rânduri AdminRole (vezi migrarea de
 * Milestone 19) - atât ele cât și rolurile CUSTOM se atribuie prin id, fără
 * distincție de tratament în DTO.
 */
export class GrantAdminRoleDto {
  @IsString()
  userId: string;

  @IsString()
  roleId: string;
}

export class UpdateAdminRoleDto {
  @IsString()
  roleId: string;
}

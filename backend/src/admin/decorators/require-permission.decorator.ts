import { SetMetadata } from '@nestjs/common';
import type { AdminPermissionKey } from '../constants/admin-permissions';

export const PERMISSION_KEY = 'requiredPermission';

export const RequirePermission = (permission: AdminPermissionKey) =>
  SetMetadata(PERMISSION_KEY, permission);

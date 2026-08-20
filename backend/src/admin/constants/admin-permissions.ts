/**
 * Catalogul de permisiuni granulare pentru Admin Control Panel (Milestone 19).
 * Fiecare AdminRole are un subset din aceste chei în AdminRole.permissions.
 * Lista e sursa de adevăr pentru validare, la fel ca FEATURE_FLAG_KEYS.
 */
export const ADMIN_PERMISSION_KEYS = [
  'users.view',
  'users.edit',
  'users.suspend',
  'users.ban',
  'users.delete',
  'books.view',
  'books.edit',
  'books.hide',
  'books.delete',
  'reports.view',
  'reports.resolve',
  'reports.dismiss',
  'exchanges.view',
  'exchanges.manage',
  'admins.view',
  'admins.create',
  'admins.edit',
  'admins.delete',
  'moderation.approve',
  'moderation.review',
] as const;

export type AdminPermissionKey = (typeof ADMIN_PERMISSION_KEYS)[number];

export function isAdminPermissionKey(value: string): value is AdminPermissionKey {
  return (ADMIN_PERMISSION_KEYS as readonly string[]).includes(value);
}

// Permisiunile predefinite pentru cele 4 roluri fixe. Folosite atât la seed-ul
// din migrare, cât și ca referință pentru front-end (rolurile predefinite nu
// se pot edita - doar CUSTOM).
export const BUILT_IN_ROLE_PERMISSIONS: Record<
  'SUPER_ADMIN' | 'MODERATOR' | 'CONTENT_MODERATOR' | 'USER_SUPPORT',
  AdminPermissionKey[]
> = {
  SUPER_ADMIN: [...ADMIN_PERMISSION_KEYS],
  MODERATOR: [
    'users.view',
    'users.suspend',
    'users.ban',
    'books.view',
    'books.hide',
    'reports.view',
    'reports.resolve',
    'reports.dismiss',
    'exchanges.view',
    'moderation.review',
  ],
  CONTENT_MODERATOR: ['books.view', 'books.edit', 'books.hide', 'reports.view', 'reports.resolve'],
  USER_SUPPORT: ['users.view', 'reports.view', 'exchanges.view'],
};

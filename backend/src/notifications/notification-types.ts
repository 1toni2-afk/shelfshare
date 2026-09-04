import { NotificationType } from '@prisma/client';

/**
 * Toate tipurile de notificare, ca listă la runtime.
 *
 * Derivată din enum-ul generat de Prisma, nu scrisă de mână: un tip nou în
 * `schema.prisma` apare automat și în setările de notificări, fără să existe
 * o a doua listă care poate rămâne în urmă.
 */
export const NOTIFICATION_TYPES = Object.values(
  NotificationType,
) as NotificationType[];

export function isNotificationType(value: string): value is NotificationType {
  return (NOTIFICATION_TYPES as string[]).includes(value);
}

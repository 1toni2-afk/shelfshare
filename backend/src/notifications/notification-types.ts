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

/**
 * Tipuri care NU apar în ecranul de setări, fiecare din alt motiv:
 *
 * - `ADMIN_MESSAGE` e răspunsul echipei la ceva ce a cerut userul însuși.
 *   Un comutator aici ar însemna „nu vreau să aflu ce mi s-a răspuns".
 * - `INTEREST_BOOK_LISTED` nu se mai trimite deloc (vezi BooksService -
 *   anunța fiecare carte dintr-un gen bifat la onboarding, adică exact
 *   spamul reclamat). Rândurile vechi rămân în istoric, dar n-are rost un
 *   comutator pentru ceva ce nu se mai naște.
 *
 * Ascunse înseamnă și needitabile: `setPreferences` le refuză, ca un client
 * mai vechi (sau construit de mână) să nu poată opri ce nu se poate opri.
 */
export const HIDDEN_NOTIFICATION_TYPES: readonly NotificationType[] = [
  'ADMIN_MESSAGE',
  'INTEREST_BOOK_LISTED',
];

/** Tipurile pe care userul chiar le poate comuta din Setări. */
export const CONFIGURABLE_NOTIFICATION_TYPES = NOTIFICATION_TYPES.filter(
  (type) => !HIDDEN_NOTIFICATION_TYPES.includes(type),
);

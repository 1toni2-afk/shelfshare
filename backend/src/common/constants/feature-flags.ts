/**
 * Cheile de „feature flag" per user - funcții încă în rulare, la care
 * proprietarul produsului poate da acces preferențial / beta din panoul de
 * admin (vezi UserFeatureFlag din schema.prisma).
 *
 * Lista e sursa de adevăr pentru validare: orice cheie trimisă de client și
 * neaflată aici e respinsă, iar rândurile vechi cu chei scoase din listă sunt
 * pur și simplu ignorate la citire. Ca să adaugi o funcție nouă e destul o
 * intrare aici (plus una identică în frontend, kFeatureFlagKeys) - fără
 * migrare de bază de date.
 */
export const ADVANCED_STATISTICS_FLAG = 'advanced_statistics';

export const FEATURE_FLAG_KEYS = [ADVANCED_STATISTICS_FLAG] as const;

export type FeatureFlagKey = (typeof FEATURE_FLAG_KEYS)[number];

export function isFeatureFlagKey(value: string): value is FeatureFlagKey {
  return (FEATURE_FLAG_KEYS as readonly string[]).includes(value);
}

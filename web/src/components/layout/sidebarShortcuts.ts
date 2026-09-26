/**
 * Scurtăturile pe care userul și le poate pune în meniu.
 *
 * Port al shared/widgets/sidebar_shortcuts.dart. Ordinea din listă e ordinea
 * din dialogul de editare; ordinea AFIȘATĂ e cea de adăugare, ca o scurtătură
 * nouă să apară la capăt, nu în mijloc.
 */
export interface ShortcutSpec {
  key: string;
  route: string;
  labelKey: string;
  /** Ascunsă pentru cine n-are dreptul (Premium, admin sau flag acordat). */
  requiresAdvancedStats?: boolean;
}

export const SHORTCUT_SPECS: ShortcutSpec[] = [
  { key: 'myBooks', route: '/bookshelf', labelKey: 'bookshelfTitle' },
  { key: 'exchanges', route: '/exchanges', labelKey: 'navMyExchanges' },
  { key: 'wishlist', route: '/wishlist', labelKey: 'navWishlist' },
  { key: 'collections', route: '/collections', labelKey: 'collectionsTitle' },
  { key: 'activityFeed', route: '/activity-feed', labelKey: 'activityFeedTitle' },
  { key: 'smartMatches', route: '/smart-matches', labelKey: 'smartMatchesTitle' },
  { key: 'following', route: '/following', labelKey: 'shortcutFollowing' },
  { key: 'leaderboard', route: '/leaderboard', labelKey: 'shortcutLeaderboard' },
  { key: 'globalStats', route: '/global-stats', labelKey: 'globalStatsTitle' },
  { key: 'map', route: '/map', labelKey: 'mapTitle' },
  { key: 'groups', route: '/groups', labelKey: 'groupsTitle' },
  {
    key: 'sellerAnalytics',
    route: '/seller-analytics',
    labelKey: 'shortcutSellerAnalytics',
    requiresAdvancedStats: true,
  },
  { key: 'trash', route: '/library/trash', labelKey: 'shortcutTrash' },
];

const DEFAULT_SHORTCUTS = ['myBooks', 'exchanges', 'wishlist'];

/**
 * Aceeași cheie ca în Flutter (`sidebar_shortcuts_v1`), dar în localStorage,
 * nu în secure storage: e o preferință de afișare, nu un secret.
 */
const STORAGE_KEY = 'sidebar_shortcuts_v1';

export function readShortcuts(): string[] {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULT_SHORTCUTS;
    const parsed = raw
      .split(',')
      .map((value) => value.trim())
      .filter((value) => SHORTCUT_SPECS.some((spec) => spec.key === value));
    // Lista golită complet de user rămâne goală; doar una invalidă cade pe
    // implicit. Fără distincția asta, „le-am scos pe toate" s-ar anula singur
    // la următoarea încărcare.
    return parsed.length > 0 || raw === '' ? parsed : DEFAULT_SHORTCUTS;
  } catch {
    return DEFAULT_SHORTCUTS;
  }
}

export function writeShortcuts(keys: string[]): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, keys.join(','));
  } catch {
    /* storage blocat - alegerea ține doar cât sesiunea */
  }
}

/**
 * Scurtăturile pe care userul CHIAR le poate deschide acum. Una salvată cândva
 * poate să nu mai fie accesibilă (ex. „Analize vânzător" după ce expiră
 * Premium-ul) - lăsată în meniu, ar duce garantat într-un 403.
 */
export function availableShortcuts(canAccessAdvancedStats: boolean): ShortcutSpec[] {
  return SHORTCUT_SPECS.filter(
    (spec) => !spec.requiresAdvancedStats || canAccessAdvancedStats,
  );
}

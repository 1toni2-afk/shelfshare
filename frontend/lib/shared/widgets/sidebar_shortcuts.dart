import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/locale/l10n_extensions.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';

/// Toate scurtăturile disponibile pentru sidebar. Enum-ul e sursa unică de
/// adevăr: același ID e folosit și în UI, și în stocare, iar orice adăugare
/// aici apare automat în selectorul de scurtături fără alte modificări.
enum SidebarShortcut {
  myBooks,
  exchanges,
  wishlist,
  collections,
  activityFeed,
  smartMatches,
  following,
  leaderboard,
  globalStats,
  map,
  groups,
  sellerAnalytics,
  preRegister,
  trash,
}

/// Metadate afișabile pentru fiecare scurtătură. Menținem etichetele l10n
/// aici (nu în enum) ca să nu duplicăm logica de traducere între sidebar-ul
/// permanent și modalul de „adaugă scurtătură".
class SidebarShortcutSpec {
  const SidebarShortcutSpec({
    required this.key,
    required this.icon,
    required this.activeIcon,
    required this.route,
    required this.labelOf,
  });

  final SidebarShortcut key;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final String Function(AppLocalizations l10n) labelOf;
}

/// Definițiile complete pentru toate scurtăturile. Ordinea aici e ordinea
/// în care apar în modalul de „adaugă".
final List<SidebarShortcutSpec> kSidebarShortcutSpecs = [
  SidebarShortcutSpec(
    key: SidebarShortcut.myBooks,
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories,
    route: '/bookshelf',
    labelOf: (l) => l.navMyBooks,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.exchanges,
    icon: Icons.swap_horiz_outlined,
    activeIcon: Icons.swap_horiz,
    route: '/exchanges',
    labelOf: (l) => l.navMyExchanges,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.wishlist,
    icon: Icons.favorite_border,
    activeIcon: Icons.favorite,
    route: '/wishlist',
    labelOf: (l) => l.navWishlist,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.collections,
    icon: Icons.collections_bookmark_outlined,
    activeIcon: Icons.collections_bookmark,
    route: '/collections',
    labelOf: (l) => l.navMyCollections,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.activityFeed,
    icon: Icons.dynamic_feed_outlined,
    activeIcon: Icons.dynamic_feed,
    route: '/activity-feed',
    labelOf: (l) => l.activityFeedTitle,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.smartMatches,
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    route: '/smart-matches',
    labelOf: (l) => l.smartMatchesTitle,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.following,
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    route: '/following',
    labelOf: (l) => l.shortcutFollowing,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.leaderboard,
    icon: Icons.leaderboard_outlined,
    activeIcon: Icons.leaderboard,
    route: '/leaderboard',
    labelOf: (l) => l.shortcutLeaderboard,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.globalStats,
    icon: Icons.query_stats_outlined,
    activeIcon: Icons.query_stats,
    route: '/global-stats',
    labelOf: (l) => l.globalStatsTitle,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.map,
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    route: '/map',
    labelOf: (l) => l.mapTitle,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.groups,
    icon: Icons.groups_outlined,
    activeIcon: Icons.groups,
    route: '/groups',
    labelOf: (l) => l.groupsTitle,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.sellerAnalytics,
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights,
    route: '/seller-analytics',
    labelOf: (l) => l.shortcutSellerAnalytics,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.preRegister,
    icon: Icons.event_available_outlined,
    activeIcon: Icons.event_available,
    route: '/pre-register',
    labelOf: (l) => l.shortcutPreRegister,
  ),
  SidebarShortcutSpec(
    key: SidebarShortcut.trash,
    icon: Icons.delete_outline,
    activeIcon: Icons.delete,
    route: '/library/trash',
    labelOf: (l) => l.shortcutTrash,
  ),
];

SidebarShortcutSpec specFor(SidebarShortcut key) =>
    kSidebarShortcutSpecs.firstWhere((s) => s.key == key);

/// Setul afișat implicit celor care nu au personalizat sidebar-ul (4 scurtături
/// istorice + reflectă ce era hardcodat înainte de Milestone 16).
const List<SidebarShortcut> _defaultShortcuts = [
  SidebarShortcut.myBooks,
  SidebarShortcut.exchanges,
  SidebarShortcut.wishlist,
  SidebarShortcut.collections,
];

/// Cheia sub care persistăm lista în secure storage. Aceleași chei
/// (nume:valoare) ca și pentru access token - un array serializat CSV.
const _storageKey = 'sidebar_shortcuts_v1';

/// Notifier peste lista de scurtături din sidebar. Persistă alegerea în
/// secure storage - același container ca și tokenurile, ca să nu adăugăm
/// încă un pachet doar pentru câteva chei de UI.
class SidebarShortcutsController extends Notifier<List<SidebarShortcut>> {
  @override
  List<SidebarShortcut> build() {
    // Pornim de la lista implicită iar `_load` va înlocui state-ul asincron
    // când valoarea persistată e disponibilă. UI-ul afișează defaultul cât
    // ține read-ul (câteva zeci de ms), fără flash gol.
    Future.microtask(_load);
    return _defaultShortcuts;
  }

  Future<void> _load() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final raw = await storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return;
      final loaded = raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => SidebarShortcut.values
              .firstWhere((v) => v.name == s, orElse: () => SidebarShortcut.myBooks))
          .toSet()
          .toList();
      if (loaded.isNotEmpty) state = loaded;
    } catch (_) {
      // Nu blocăm sidebar-ul dacă read-ul eșuează - rămânem pe default.
    }
  }

  Future<void> _save() async {
    try {
      final storage = ref.read(secureStorageProvider);
      await storage.write(
        key: _storageKey,
        value: state.map((s) => s.name).join(','),
      );
    } catch (_) {
      // Best-effort; nu afișăm eroare pentru un fail de persistență minor.
    }
  }

  void add(SidebarShortcut key) {
    if (state.contains(key)) return;
    state = [...state, key];
    _save();
  }

  void remove(SidebarShortcut key) {
    state = state.where((k) => k != key).toList();
    _save();
  }
}

final sidebarShortcutsProvider =
    NotifierProvider<SidebarShortcutsController, List<SidebarShortcut>>(
  SidebarShortcutsController.new,
);

/// Modalul de „adaugă scurtătură" - listă cu scurtăturile care nu sunt
/// deja în sidebar. Închis fără selecție = nicio modificare.
Future<void> showAddShortcutSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(sidebarShortcutsProvider);
  final available = kSidebarShortcutSpecs
      .where((s) => !current.contains(s.key))
      .toList();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      if (available.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.shortcutsAllAdded,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                l10n.shortcutsAddTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: available.length,
                itemBuilder: (context, index) {
                  final spec = available[index];
                  return ListTile(
                    leading: Icon(spec.icon),
                    title: Text(spec.labelOf(l10n)),
                    onTap: () {
                      ref.read(sidebarShortcutsProvider.notifier).add(spec.key);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

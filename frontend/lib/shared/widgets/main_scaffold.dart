import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/exchange_request.dart';
import '../../data/models/price_offer.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/chat/application/conversations_controller.dart';
import '../../features/exchanges/application/exchanges_controller.dart';
import '../../features/notifications/application/notifications_controller.dart';
import '../../features/offers/application/offers_controller.dart';
import '../../features/profile/application/profile_controller.dart';

/// Ecran mai lat de-atât înseamnă „desktop" - sub, sidebar-ul devine drawer.
const kSidebarBreakpoint = 900.0;

/// Lățimea sidebar-ului pe desktop. Egală cu ce am folosit pe mockup.
const kSidebarWidth = 240.0;

/// Shell principal al aplicației după autentificare: pe desktop sidebar
/// permanent stânga, pe mobil același conținut într-un `Drawer` (hamburger
/// în AppBar). Am renunțat la `NavigationBar` de jos - Milestone 17: sidebar
/// peste tot, cum e în mockup.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= kSidebarBreakpoint;
    final sidebar = _Sidebar(navigationShell: navigationShell);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: kSidebarWidth, child: sidebar),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    // Pe mobil: același sidebar într-un drawer. Nav-ul e ce vine implicit
    // în AppBar-ul fiecărui ecran (Scaffold.drawer face automat hamburger).
    return Scaffold(
      drawer: SizedBox(width: kSidebarWidth, child: Drawer(child: sidebar)),
      body: navigationShell,
    );
  }
}

/// Sidebar-ul, folosit atât în layout-ul de desktop cât și în drawer-ul de
/// mobil. Structurat pe trei zone: nav principal (Home, Discover, My Shelf,
/// Chat, Notificări), secțiune „Scurtături" (linkuri către pagini legate),
/// și un footer (Settings, Help, avatarul userului).
class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // Badge-uri urmărite direct din shell (mereu montat), ca numerele să fie
    // corecte indiferent de tab-ul curent - nu doar după ce userul deschide
    // ecranul respectiv.
    final chatUnread = ref.watch(unreadMessagesCountProvider);
    final libraryPending =
        (ref.watch(exchangesControllerProvider).value?.received ?? const [])
                .where((r) => r.status == ExchangeStatus.pending)
                .length +
            (ref.watch(offersControllerProvider).value?.received ?? const [])
                .where((o) => o.status == OfferStatus.pending)
                .length;
    final notificationsUnread =
        (ref.watch(notificationsControllerProvider).value ?? const [])
            .where((n) => !n.isRead)
            .length;

    final mainNav = <_NavItem>[
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: l10n.navHome,
        branchIndex: 0,
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: l10n.navSearch,
        branchIndex: 1,
      ),
      _NavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: l10n.navLibrary,
        branchIndex: 2,
        badge: libraryPending,
      ),
      _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: l10n.navChat,
        branchIndex: 3,
        badge: chatUnread,
      ),
      _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: l10n.navNotifications,
        route: '/notifications',
        badge: notificationsUnread,
      ),
    ];

    final shortcuts = <_NavItem>[
      _NavItem(
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories,
        label: l10n.navMyBooks,
        route: '/bookshelf',
      ),
      _NavItem(
        icon: Icons.swap_horiz_outlined,
        activeIcon: Icons.swap_horiz,
        label: l10n.navMyExchanges,
        route: '/exchanges',
      ),
      _NavItem(
        icon: Icons.favorite_border,
        activeIcon: Icons.favorite,
        label: l10n.navWishlist,
        route: '/wishlist',
      ),
      _NavItem(
        icon: Icons.collections_bookmark_outlined,
        activeIcon: Icons.collections_bookmark,
        label: l10n.navMyCollections,
        route: '/collections',
      ),
    ];

    return Container(
      color: AppColors.card,
      child: SafeArea(
        child: Column(
          children: [
            // Antet cu logo.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ShelfShare',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final item in mainNav)
                    _SidebarTile(
                      item: item,
                      isActive: _isActive(item),
                      onTap: () => _navigate(context, item),
                    ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      l10n.navShortcuts,
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in shortcuts)
                    _SidebarTile(
                      item: item,
                      isActive: false,
                      onTap: () => _navigate(context, item),
                    ),
                ],
              ),
            ),
            // Footer: Setări, Help, avatarul userului (ultimul deschide profilul).
            _SidebarTile(
              item: _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: l10n.profileSettings,
                route: '/profile/settings',
              ),
              isActive: false,
              onTap: () => context.push('/profile/settings'),
            ),
            _SidebarTile(
              item: _NavItem(
                icon: Icons.help_outline,
                activeIcon: Icons.help,
                label: l10n.profileHelpCenter,
                route: '/help-center',
              ),
              isActive: false,
              onTap: () => context.push('/help-center'),
            ),
            const Divider(height: 1),
            _ProfileFooter(navigationShell: navigationShell),
          ],
        ),
      ),
    );
  }

  bool _isActive(_NavItem item) {
    if (item.branchIndex == null) return false;
    return item.branchIndex == navigationShell.currentIndex;
  }

  void _navigate(BuildContext context, _NavItem item) {
    // Închide drawer-ul dacă suntem pe mobil - altfel după tap ar rămâne
    // deschis peste noul ecran.
    if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
      Navigator.of(context).pop();
    }
    if (item.branchIndex != null) {
      navigationShell.goBranch(
        item.branchIndex!,
        initialLocation: item.branchIndex == navigationShell.currentIndex,
      );
    } else if (item.route != null) {
      context.push(item.route!);
    }
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.branchIndex,
    this.route,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Tab-ul (0-4) dacă e o destinație principală din shell. Exclusiv cu [route].
  final int? branchIndex;

  /// Rută push dacă e o legătură secundară. Exclusiv cu [branchIndex].
  final String? route;

  final int badge;
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? AppColors.accent.withValues(alpha: 0.15) : null;
    final fg = isActive ? AppColors.accent : AppColors.foreground;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(isActive ? item.activeIcon : item.icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (item.badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.badge}',
                  style: const TextStyle(
                    color: AppColors.accentForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Footer-ul cu avatarul userului - tap îi duce în tab-ul de profil. Reia
/// datele din providerul de profil, deci imaginea se schimbă live după upload.
class _ProfileFooter extends ConsumerWidget {
  const _ProfileFooter({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileControllerProvider).value ??
        (ref.watch(authControllerProvider) is AuthAuthenticated
            ? (ref.watch(authControllerProvider) as AuthAuthenticated).user
            : null);
    if (user == null) return const SizedBox.shrink();

    // Tab-ul de profil e index 4 în shell.
    const profileBranch = 4;
    final isActive = navigationShell.currentIndex == profileBranch;

    return InkWell(
      onTap: () => navigationShell.goBranch(profileBranch,
          initialLocation: isActive),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.muted,
              backgroundImage: user.profileImage != null
                  ? NetworkImage(user.profileImage!)
                  : null,
              child: user.profileImage == null
                  ? Icon(Icons.person, color: AppColors.mutedForeground, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (user.name?.trim().isNotEmpty ?? false) ? user.name! : user.email,
                    style: TextStyle(
                      color: AppColors.foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.username != null)
                    Text(
                      '@${user.username}',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

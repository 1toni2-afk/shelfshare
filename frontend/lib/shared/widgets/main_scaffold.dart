import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/chat/application/conversations_controller.dart';
import '../../features/notifications/application/notifications_controller.dart';
import '../../features/profile/application/profile_controller.dart';
import 'sidebar_shortcuts.dart';

/// Ecran mai lat de-atât înseamnă „desktop" - sub, sidebar-ul devine drawer.
const kSidebarBreakpoint = 900.0;

/// Lățimea sidebar-ului pe desktop. Egală cu ce am folosit pe mockup.
const kSidebarWidth = 240.0;

/// Cheie stabilă pentru Scaffold-ul exterior (cel cu drawer-ul), instanțiată
/// o singură dată la nivel de modul - MainScaffold e shell-ul unic al
/// aplicației, deci o singură instanță trăiește la un moment dat.
///
/// De ce: pe mobil/web îngust, fiecare ecran (child) are PROPRIUL Scaffold
/// cu propriul AppBar. Hamburger-ul automat din AppBar caută cel mai apropiat
/// Scaffold ANCESTOR - găsește Scaffold-ul intern al ecranului (fără drawer),
/// nu pe cel exterior care are drawer-ul cu meniul. Rezultat: pe telefon/web
/// îngust nu exista nicio cale să deschizi meniul din stânga. Butonul flotant
/// de mai jos apelează direct starea acestui Scaffold, deci funcționează
/// indiferent de AppBar-ul ecranului curent.
final _shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Shell principal al aplicației după autentificare: pe desktop sidebar
/// permanent stânga, pe mobil același conținut într-un `Drawer` (hamburger
/// în AppBar).
///
/// Randăm sidebar-ul în afara `StatefulShellRoute` (vezi app_router.dart):
/// pentru orice rută autentificată, sidebar-ul rămâne vizibil și doar zona
/// dreaptă (child) se schimbă. Milestone 16: bug-ul „meniul dispare când dau
/// click pe Notificări" era exact asta - notificările erau pe o rută
/// standalone care înlocuia tot MainScaffold.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  final Widget child;
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= kSidebarBreakpoint;
    final sidebar = _Sidebar(currentLocation: currentLocation);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: kSidebarWidth, child: sidebar),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    // Pe mobil/web îngust: același sidebar într-un drawer. Nu ne bazăm pe
    // hamburger-ul automat al AppBar-ului (fiecare ecran are propriul
    // Scaffold, care „umbrește" drawer-ul celui exterior - vezi comentariul
    // de la `_shellScaffoldKey`) - butonul flotant de mai jos deschide
    // drawer-ul direct, indiferent de ecranul curent.
    //
    // Rămâne mereu vizibil, pe orice ecran - varianta anterioară îl ascundea
    // când `canPop()` era true (ecrane deschise cu push, ex. detaliul unei
    // cărți), presupunând că AppBar-ul acelui ecran are deja o săgeată de
    // back. În practică, după ce userul apăsa acel back și revenea la un
    // ecran „rădăcină", butonul rămânea dispărut - fără nicio cale de a mai
    // deschide meniul. Când există și o săgeată de back, butonul se mută
    // puțin la dreapta ei, în loc să dispară.
    final canPop = context.canPop();
    return Scaffold(
      key: _shellScaffoldKey,
      // Lățime mai mare pentru gestul de swipe-din-margine: cea implicită din
      // Flutter (20dp) e prea îngustă ca să fie ușor de nimerit pe telefon.
      // Bumped 48 -> 96 (Milestone 23 Buggs #3): 48dp tot era prea îngust în
      // practică - userul trebuia să nimerească aproape exact marginea
      // ecranului. O bandă de aproape un sfert din lățimea unui telefon tipic
      // dă mult mai multă marjă de eroare, fără să intre în conflict cu
      // conținut orizontal scrollabil (acela stă de regulă mai spre centru).
      drawerEdgeDragWidth: 96,
      drawer: SizedBox(width: kSidebarWidth, child: Drawer(child: sidebar)),
      body: Stack(
        children: [
          child,
          Positioned(
            left: canPop ? 52 : 8,
            top: 8,
            child: SafeArea(
              child: _MenuFab(onTap: () => _shellScaffoldKey.currentState?.openDrawer()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Buton flotant care deschide meniul din stânga pe mobil/web îngust, poziționat
/// sus-stânga - același colț unde ecranele cu back-button au deja săgeata,
/// dar vizibil doar când NU există un back-button (vezi `canPop` mai sus).
class _MenuFab extends StatelessWidget {
  const _MenuFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(Icons.menu, color: AppColors.foreground, size: 22),
        ),
      ),
    );
  }
}

/// Sidebar-ul, folosit atât în layout-ul de desktop cât și în drawer-ul de
/// mobil. Structurat pe trei zone: nav principal (Home, Discover, My Shelf,
/// Chat, Notificări), secțiune „Scurtături" (linkuri către pagini legate),
/// și un footer (Settings, Help, avatarul userului).
class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({required this.currentLocation});
  final String currentLocation;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  /// Modul de editare a secțiunii „Scurtături". Nu se persistă - user-ul iese
  /// din el fie prin butonul „Gata", fie navigând la altă rută (montarea se
  /// rezetează). Un flag pe StatefulWidget e mai simplu decât un provider
  /// dedicat pentru ceva ce ține doar de sesiunea vizuală curentă.
  bool _editingShortcuts = false;

  String get currentLocation => widget.currentLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Badge-uri urmărite direct - MainScaffold e mereu montat, deci numerele
    // sunt corecte indiferent de tab-ul curent.
    //
    // Cererile de schimb/ofertele pending NU mai au badge propriu pe My Shelf
    // (Milestone 19): userul primea „1" simultan pe My Shelf, Chat și
    // clopoțel pentru același eveniment. Cererile de schimb au acum un
    // singur canal - notificarea din clopoțel (+ push); ofertele de preț se
    // văd oricum ca mesaj în conversație.
    final chatUnread = ref.watch(unreadMessagesCountProvider);
    final notificationsUnread =
        (ref.watch(notificationsControllerProvider).value ?? const [])
            .where((n) => !n.isRead)
            .length;

    final mainNav = <_NavItem>[
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: l10n.navHome,
        route: '/',
      ),
      _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: l10n.navSearch,
        route: '/search',
      ),
      _NavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: l10n.navLibrary,
        route: '/library',
      ),
      _NavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: l10n.navChat,
        route: '/chat',
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

    // Lista de scurtături e alegerea userului (persistată în secure storage).
    // Ordinea corespunde cu ordinea de adăugare - noile scurtături apar la
    // capăt, nu se re-sortează după enum.
    final shortcutKeys = ref.watch(sidebarShortcutsProvider);
    final shortcuts = [
      for (final key in shortcutKeys)
        () {
          final spec = specFor(key);
          return _NavItem(
            icon: spec.icon,
            activeIcon: spec.activeIcon,
            label: spec.labelOf(l10n),
            route: spec.route,
          );
        }(),
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
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
                        IconButton(
                          iconSize: 16,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          tooltip: _editingShortcuts
                              ? l10n.shortcutsDoneTooltip
                              : l10n.shortcutsEditTooltip,
                          icon: Icon(
                            _editingShortcuts ? Icons.check : Icons.edit_outlined,
                            color: AppColors.mutedForeground,
                          ),
                          onPressed: () => setState(
                              () => _editingShortcuts = !_editingShortcuts),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < shortcuts.length; i++)
                    _SidebarTile(
                      item: shortcuts[i],
                      isActive: _isActive(shortcuts[i]),
                      onTap: _editingShortcuts
                          ? () {}
                          : () => _navigate(context, shortcuts[i]),
                      onRemove: _editingShortcuts
                          ? () => ref
                              .read(sidebarShortcutsProvider.notifier)
                              .remove(shortcutKeys[i])
                          : null,
                    ),
                  if (_editingShortcuts)
                    _AddShortcutTile(
                      onTap: () => showAddShortcutSheet(context, ref),
                    ),
                ],
              ),
            ),
            // Footer: Setări, Help, avatarul userului.
            _SidebarTile(
              item: _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: l10n.profileSettings,
                route: '/settings',
              ),
              isActive: currentLocation == '/settings',
              onTap: () => _goTo(context, '/settings'),
            ),
            _SidebarTile(
              item: _NavItem(
                icon: Icons.info_outline,
                activeIcon: Icons.info,
                label: l10n.navAboutApp,
                route: '/about-app',
              ),
              isActive: currentLocation == '/about-app',
              onTap: () => _goTo(context, '/about-app'),
            ),
            _SidebarTile(
              item: _NavItem(
                icon: Icons.help_outline,
                activeIcon: Icons.help,
                label: l10n.profileHelpCenter,
                route: '/help-center',
              ),
              isActive: currentLocation == '/help-center',
              onTap: () => _goTo(context, '/help-center'),
            ),
            const Divider(height: 1),
            _ProfileFooter(currentLocation: currentLocation),
          ],
        ),
      ),
    );
  }

  /// Marchează tile-ul activ dacă ruta curentă începe cu ruta lui - astfel
  /// sub-navigările din interiorul unui branch păstrează evidențierea (ex.
  /// când user-ul e pe /library/add, tile-ul „Raftul meu" rămâne activ).
  bool _isActive(_NavItem item) {
    if (item.route == '/') return currentLocation == '/';
    return currentLocation == item.route ||
        currentLocation.startsWith('${item.route}/');
  }

  void _navigate(BuildContext context, _NavItem item) {
    _goTo(context, item.route);
  }

  /// Închidem drawer-ul dacă suntem pe mobil (altfel după tap ar rămâne
  /// deschis peste noul ecran), apoi `go` la rută. `go`, nu `push`: sidebar-ul
  /// e la nivel de shell exterior, deci URL-ul se înlocuiește curat și
  /// tab-urile Home/Discover/Chat nu-și mai amintesc o vizită la Settings.
  void _goTo(BuildContext context, String route) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.hasDrawer && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
    context.go(route);
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.badge = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final int badge;
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.onRemove,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  /// Când e setat, arătăm un buton X în colțul din dreapta al tile-ului.
  /// Modul de editare al secțiunii „Scurtături" îl folosește pentru a scoate
  /// scurtătura din listă. Când e null, tile-ul are aspectul obișnuit.
  final VoidCallback? onRemove;

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
            if (onRemove == null && item.badge > 0)
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
            if (onRemove != null)
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tile-ul „+" afișat sub scurtături în mod editare - deschide selectorul cu
/// scurtăturile care nu sunt încă în listă.
class _AddShortcutTile extends StatelessWidget {
  const _AddShortcutTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 20, color: AppColors.mutedForeground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.shortcutsAddTitle,
                style: TextStyle(
                  color: AppColors.mutedForeground,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer-ul cu avatarul userului - tap îi duce în tab-ul de profil.
class _ProfileFooter extends ConsumerWidget {
  const _ProfileFooter({required this.currentLocation});
  final String currentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileControllerProvider).value ??
        (ref.watch(authControllerProvider) is AuthAuthenticated
            ? (ref.watch(authControllerProvider) as AuthAuthenticated).user
            : null);
    if (user == null) return const SizedBox.shrink();

    final isActive = currentLocation.startsWith('/profile');

    return InkWell(
      onTap: () {
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.hasDrawer && scaffold.isDrawerOpen) {
          Navigator.of(context).pop();
        }
        context.go('/profile');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isActive ? AppColors.accent.withValues(alpha: 0.08) : null,
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

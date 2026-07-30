import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/locale/l10n_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/exchange_request.dart';
import '../../data/models/price_offer.dart';
import '../../features/chat/application/conversations_controller.dart';
import '../../features/exchanges/application/exchanges_controller.dart';
import '../../features/offers/application/offers_controller.dart';

/// Lățimea maximă a blocului de destinații din bara de jos. Pe telefon bara e
/// oricum mai îngustă decât atât, deci constrângerea nu se simte; pe desktop
/// ține cele 5 iconițe grupate în mijloc.
const kBottomNavMaxWidth = 560.0;

/// Scaffold cu bottom navigation, folosit ca "shell" pentru cele 5 tab-uri
/// principale (Home, Caută, Biblioteca mea, Chat, Profil) - la fel ca în
/// designul din Figma.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // Urmărite direct din shell (mereu montat) ca badge-urile să fie corecte
    // indiferent de tab-ul curent, nu doar după ce userul deschide Chat/Library.
    final chatUnread = ref.watch(unreadMessagesCountProvider);
    final libraryPending =
        (ref.watch(exchangesControllerProvider).value?.received ?? const [])
                .where((r) => r.status == ExchangeStatus.pending)
                .length +
            (ref.watch(offersControllerProvider).value?.received ?? const [])
                .where((o) => o.status == OfferStatus.pending)
                .length;

    final destinations = [
      (icon: Icons.home_outlined, activeIcon: Icons.home, label: l10n.navHome, badge: 0),
      (icon: Icons.explore_outlined, activeIcon: Icons.explore, label: l10n.navSearch, badge: 0),
      (
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: l10n.navLibrary,
        badge: libraryPending,
      ),
      (
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: l10n.navChat,
        badge: chatUnread,
      ),
      (icon: Icons.person_outline, activeIcon: Icons.person, label: l10n.navProfile, badge: 0),
    ];

    return Scaffold(
      body: navigationShell,
      // Bara nu se mai întinde pe toată lățimea ecranului: pe desktop, cele 5
      // destinații erau împrăștiate la câteva sute de pixeli una de alta.
      // Rămâne un bloc de lățime fixă, centrat, cu fundalul barei păstrat pe
      // toată lățimea ca să nu apară o dungă de altă culoare pe margini.
      bottomNavigationBar: ColoredBox(
        color: AppColors.card,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kBottomNavMaxWidth),
            child: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.accent.withValues(alpha: 0.15),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Badge(
                label: Text('${d.badge}'),
                isLabelVisible: d.badge > 0,
                child: Icon(d.icon),
              ),
              selectedIcon: Badge(
                label: Text('${d.badge}'),
                isLabelVisible: d.badge > 0,
                child: Icon(d.activeIcon, color: AppColors.primary),
              ),
              label: d.label,
            ),
        ],
            ),
          ),
        ),
      ),
    );
  }
}

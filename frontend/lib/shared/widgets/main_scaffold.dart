import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Scaffold cu bottom navigation, folosit ca "shell" pentru cele 5 tab-uri
/// principale (Home, Caută, Biblioteca mea, Chat, Profil) - la fel ca în
/// designul din Figma.
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Acasă'),
    (icon: Icons.search_outlined, activeIcon: Icons.search, label: 'Caută'),
    (icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book, label: 'Biblioteca'),
    (icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chat'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.accent.withValues(alpha: 0.15),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.activeIcon, color: AppColors.primary),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// The bottom-nav branch index currently shown. Pages that need to know whether
/// they're the visible tab (e.g. Reels, to stop video playing in the background)
/// listen to this. Reels is branch index 3.
final shellTabIndex = ValueNotifier<int>(0);

/// Main navigation shell: bottom tab bar on compact screens, side rail on
/// wide screens (web/desktop). The five destinations mirror prot_3's
/// SwipePager sections: Home, Explore, Create hub, Reels, Profile —
/// swiping between the top-level branches is handled by the branch pages.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.home_outlined, active: Icons.home, label: 'Home'),
    (icon: Icons.search_outlined, active: Icons.search, label: 'Explore'),
    (icon: Icons.add_box_outlined, active: Icons.add_box, label: 'Create'),
    (icon: Icons.movie_creation_outlined, active: Icons.movie_creation, label: 'Reels'),
    (icon: Icons.person_outline, active: Icons.person, label: 'Profile'),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Publish the active tab after the frame (avoids notifying mid-build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shellTabIndex.value != navigationShell.currentIndex) {
        shellTabIndex.value = navigationShell.currentIndex;
      }
    });
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: KliqColors.background,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onTap,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    KliqLogo(size: 42),
                    SizedBox(height: 8),
                    KliqWordmark(size: 13),
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.active),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 0.5),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: [
          for (final d in _destinations)
            BottomNavigationBarItem(
              icon: Icon(d.icon),
              activeIcon: Icon(d.active),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

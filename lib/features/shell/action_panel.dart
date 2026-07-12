import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// The "second side panel": a right-hand slide-in menu opened from the user's
/// avatar in the app bar. Shows the user header, quick links to every current
/// KLIQ surface, and Sign Out. Rebuilt after the Instagram-style slim-down so
/// it only links to components that still exist.
Future<void> showActionPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Menu',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim, secondary) => Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 320,
        height: double.infinity,
        child: Material(color: KliqColors.surface, child: const _ActionPanel()),
      ),
    ),
    transitionBuilder: (context, anim, secondary, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: child,
    ),
  );
}

/// Avatar button for app bars that opens the action panel.
class ActionPanelButton extends StatelessWidget {
  const ActionPanelButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user ?? {};
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => showActionPanel(context),
        child: Container(
          decoration: const BoxDecoration(
              shape: BoxShape.circle, gradient: KliqColors.storyRing),
          padding: const EdgeInsets.all(2),
          child: KliqAvatar(user['avatarUrl']?.toString(), radius: 14),
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel();

  // Only current, live surfaces. `tab: true` entries switch the bottom-nav
  // branch (context.go); the rest stack on top (context.push).
  static const _items = [
    (icon: Icons.person_outline, label: 'My Profile', path: '/profile', color: KliqColors.purple, tab: true),
    (icon: Icons.search, label: 'Search', path: '/search', color: KliqColors.cyan, tab: false),
    (icon: Icons.explore_outlined, label: 'Explore', path: '/explore', color: Color(0xFF60A5FA), tab: true),
    (icon: Icons.movie_creation_outlined, label: 'Reels', path: '/reels', color: KliqColors.pink, tab: true),
    (icon: Icons.live_tv_outlined, label: 'Live', path: '/live', color: KliqColors.live, tab: false),
    (icon: Icons.videocam_outlined, label: 'Go Live', path: '/go-live', color: Color(0xFFF87171), tab: false),
    (icon: Icons.send_outlined, label: 'Messages', path: '/inbox', color: KliqColors.cyan, tab: false),
    (icon: Icons.notifications_none, label: 'Notifications', path: '/notifications', color: KliqColors.warning, tab: false),
    (icon: Icons.bookmark_border, label: 'Saved', path: '/saved', color: KliqColors.purple, tab: false),
    (icon: Icons.people_outline, label: 'Friends', path: '/friends', color: KliqColors.success, tab: false),
    (icon: Icons.settings_outlined, label: 'Settings & Privacy', path: '/settings', color: KliqColors.textSecondary, tab: false),
  ];

  void _go(BuildContext context, String path, bool tab) {
    Navigator.of(context).pop();
    if (tab) {
      context.go(path);
    } else {
      context.push(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user ?? {};
    return SafeArea(
      child: Column(
        children: [
          // ── User header ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, gradient: KliqColors.storyRing),
                  padding: const EdgeInsets.all(2),
                  child: KliqAvatar(user['avatarUrl']?.toString(), radius: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['displayName']?.toString() ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5),
                      ),
                      Text('@${user['username'] ?? '—'}',
                          style: const TextStyle(
                              color: KliqColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Menu ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                for (final item in _items)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _go(context, item.path, item.tab),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 9),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                Icon(item.icon, size: 19, color: item.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.label,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 16, color: KliqColors.textMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Footer ─────────────────────────────────────────────────
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton.icon(
              onPressed: () async {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                await session.logout();
                router.go('/login');
              },
              icon: const Icon(Icons.logout, size: 16, color: KliqColors.danger),
              label: const Text('Sign Out',
                  style: TextStyle(
                      color: KliqColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

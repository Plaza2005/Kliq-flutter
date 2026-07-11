import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// The "second side panel" from the original prot_3 app (ActionPanel.tsx):
/// a right-hand slide-in menu opened from the user's avatar, with the user
/// header, quick links to every KLIQ surface, and Switch Account / Sign Out.
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

/// Avatar button for app bars that opens the action panel — mirrors the
/// header avatar in the original layout.
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

  static const _items = [
    (icon: Icons.person_outline, label: 'My Profile', path: '/profile', color: KliqColors.purple),
    (icon: Icons.account_balance_wallet_outlined, label: 'Wallet', path: '/wallet', color: KliqColors.success),
    (icon: Icons.bar_chart, label: 'Analytics', path: '/analytics', color: Color(0xFF60A5FA)),
    (icon: Icons.download_outlined, label: 'Offline Videos', path: '/studio', color: KliqColors.purple),
    (icon: Icons.tv_outlined, label: 'Kliq Stream', path: '/kliqstream', color: KliqColors.pink),
    (icon: Icons.play_circle_outline, label: 'KliqTube', path: '/kliqtube', color: Color(0xFFF87171)),
    (icon: Icons.storefront_outlined, label: 'Marketplace', path: '/marketplace', color: KliqColors.warning),
    (icon: Icons.videocam_outlined, label: 'Kliq Studio', path: '/studio', color: KliqColors.cyan),
    (icon: Icons.trending_up, label: 'Amplify', path: '/amplify', color: Color(0xFFFB923C)),
    (icon: Icons.groups_outlined, label: 'Community', path: '/communities', color: KliqColors.purple),
    (icon: Icons.settings_outlined, label: 'Settings & Privacy', path: '/settings', color: KliqColors.textSecondary),
  ];

  void _go(BuildContext context, String path) {
    Navigator.of(context).pop();
    // Tab destinations use go (switch branch); the rest stack on top.
    if (path == '/profile' || path == '/kliqtube') {
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
                      shape: BoxShape.circle,
                      gradient: KliqColors.storyRing),
                  padding: const EdgeInsets.all(2),
                  child:
                      KliqAvatar(user['avatarUrl']?.toString(), radius: 20),
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
                    onTap: () => _go(context, item.path),
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
                            child: Icon(item.icon,
                                size: 19, color: item.color),
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
            child: Column(
              children: [
                TextButton(
                  onPressed: () => _go(context, '/settings'),
                  child: const Text('Switch Account',
                      style: TextStyle(
                          color: KliqColors.textSecondary, fontSize: 13)),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    await session.exitToEntry();
                    router.go('/entry');
                  },
                  icon: const Icon(Icons.logout,
                      size: 16, color: KliqColors.danger),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: KliqColors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

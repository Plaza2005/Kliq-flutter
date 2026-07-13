import 'package:go_router/go_router.dart';

import '../../features/auth/password_pages.dart';
import '../../features/settings/settings_pages.dart';
import '../../features/social/messaging_pages.dart';

/// Direct messaging and settings.
final socialRoutes = <RouteBase>[
  // ── Messaging ───────────────────────────────────────────────────────────
  GoRoute(path: '/inbox', builder: (c, s) => const InboxPage()),
  GoRoute(
    path: '/chat/:id',
    builder: (c, s) =>
        ChatPage(conversationId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/group/:id',
    builder: (c, s) => ChatPage(
        conversationId: s.pathParameters['id']!, isGroup: true),
  ),
  // ── Settings ────────────────────────────────────────────────────────────
  GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
  GoRoute(
      path: '/change-password',
      builder: (c, s) => const ChangePasswordPage()),
  GoRoute(
      path: '/settings/privacy',
      builder: (c, s) => const PrivacySettingsPage()),
  GoRoute(
      path: '/settings/notifications',
      builder: (c, s) => const NotificationPrefsPage()),
  GoRoute(
      path: '/settings/blocked',
      builder: (c, s) => const BlockedUsersPage()),
  GoRoute(
      path: '/settings/muted', builder: (c, s) => const MutedUsersPage()),
  GoRoute(
      path: '/settings/language',
      builder: (c, s) => const LanguageRegionPage()),
];

import 'package:go_router/go_router.dart';

import '../../features/auth/password_pages.dart';
import '../../features/settings/settings_pages.dart';
import '../../features/social/community_chat_page.dart';
import '../../features/social/messaging_pages.dart';

/// Direct messaging and settings.
final socialRoutes = <RouteBase>[
  // ── Messaging ───────────────────────────────────────────────────────────
  GoRoute(path: '/inbox', builder: (c, s) => const InboxPage()),
  GoRoute(
    path: '/chat/:id',
    // `?type=thread` means the id is an existing DM threadId (from the
    // inbox list); otherwise it's a userId to resolve/create a thread for
    // (from a profile or contacts page).
    builder: (c, s) => ChatPage(
      conversationId: s.pathParameters['id']!,
      isThreadId: s.uri.queryParameters['type'] == 'thread',
    ),
  ),
  GoRoute(
    path: '/group/:id',
    builder: (c, s) => ChatPage(
        conversationId: s.pathParameters['id']!, isGroup: true),
  ),
  GoRoute(
    path: '/community/:id',
    builder: (c, s) =>
        CommunityChatPage(communityId: s.pathParameters['id']!),
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

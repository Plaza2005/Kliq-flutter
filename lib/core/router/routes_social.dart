import 'package:go_router/go_router.dart';

import '../../features/market/marketplace_pages.dart';
import '../../features/settings/settings_pages.dart';
import '../../features/social/community_pages.dart';
import '../../features/social/messaging_pages.dart';
import '../../features/wallet/wallet_pages.dart';

/// Marketplace, wallet, communities, messaging and settings.
final socialRoutes = <RouteBase>[
  // ── Marketplace ─────────────────────────────────────────────────────────
  GoRoute(path: '/marketplace', builder: (c, s) => const MarketplacePage()),
  GoRoute(
    path: '/marketplace/product/:id',
    builder: (c, s) =>
        ProductDetailPage(productId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/marketplace/seller/:id',
    builder: (c, s) => SellerPage(sellerId: s.pathParameters['id']!),
  ),
  GoRoute(
      path: '/customize-shop',
      builder: (c, s) => const CustomizeShopPage()),
  // ── Wallet ──────────────────────────────────────────────────────────────
  GoRoute(path: '/wallet', builder: (c, s) => const WalletPage()),
  GoRoute(
      path: '/wallet/history',
      builder: (c, s) => const WalletHistoryPage()),
  GoRoute(
      path: '/wallet/orders', builder: (c, s) => const WalletOrdersPage()),
  GoRoute(path: '/payment', builder: (c, s) => const PaymentPage()),
  // ── Communities ─────────────────────────────────────────────────────────
  GoRoute(
      path: '/communities', builder: (c, s) => const CommunitiesPage()),
  GoRoute(
      path: '/create-community',
      builder: (c, s) => const CreateCommunityPage()),
  GoRoute(
    path: '/community/:id',
    builder: (c, s) =>
        CommunityPage(communityId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/community/:id/chat',
    builder: (c, s) => CommunityChatPage(
      communityId: s.pathParameters['id']!,
      channel: s.uri.queryParameters['channel'],
    ),
  ),
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

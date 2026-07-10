import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';

/// Marketplace, wallet, communities, messaging and settings.
/// Owned by the commerce/social feature team.
final socialRoutes = <RouteBase>[
  // ── Marketplace ─────────────────────────────────────────────────────────
  GoRoute(
    path: '/marketplace',
    builder: (c, s) => const PlaceholderPage(title: 'Marketplace'),
  ),
  GoRoute(
    path: '/marketplace/product/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Product', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/marketplace/seller/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Seller', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/customize-shop',
    builder: (c, s) => const PlaceholderPage(title: 'Customize Shop'),
  ),
  // ── Wallet ──────────────────────────────────────────────────────────────
  GoRoute(
    path: '/wallet',
    builder: (c, s) => const PlaceholderPage(title: 'Wallet'),
  ),
  GoRoute(
    path: '/wallet/history',
    builder: (c, s) => const PlaceholderPage(title: 'Wallet History'),
  ),
  GoRoute(
    path: '/wallet/orders',
    builder: (c, s) => const PlaceholderPage(title: 'Orders'),
  ),
  GoRoute(
    path: '/payment',
    builder: (c, s) => const PlaceholderPage(title: 'Payment'),
  ),
  // ── Communities ─────────────────────────────────────────────────────────
  GoRoute(
    path: '/communities',
    builder: (c, s) => const PlaceholderPage(title: 'Communities'),
  ),
  GoRoute(
    path: '/create-community',
    builder: (c, s) => const PlaceholderPage(title: 'Create Community'),
  ),
  GoRoute(
    path: '/community/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Community', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/community/:id/chat',
    builder: (c, s) => const PlaceholderPage(title: 'Community Chat'),
  ),
  // ── Messaging ───────────────────────────────────────────────────────────
  GoRoute(
    path: '/inbox',
    builder: (c, s) => const PlaceholderPage(title: 'Inbox'),
  ),
  GoRoute(
    path: '/chat/:id',
    builder: (c, s) =>
        PlaceholderPage(title: 'Chat', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/group/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Group Chat', subtitle: s.pathParameters['id']),
  ),
  // ── Settings ────────────────────────────────────────────────────────────
  GoRoute(
    path: '/settings',
    builder: (c, s) => const PlaceholderPage(title: 'Settings'),
  ),
  GoRoute(
    path: '/settings/privacy',
    builder: (c, s) => const PlaceholderPage(title: 'Privacy'),
  ),
  GoRoute(
    path: '/settings/notifications',
    builder: (c, s) => const PlaceholderPage(title: 'Notification Preferences'),
  ),
  GoRoute(
    path: '/settings/blocked',
    builder: (c, s) => const PlaceholderPage(title: 'Blocked Users'),
  ),
  GoRoute(
    path: '/settings/muted',
    builder: (c, s) => const PlaceholderPage(title: 'Muted Users'),
  ),
  GoRoute(
    path: '/settings/language',
    builder: (c, s) => const PlaceholderPage(title: 'Language & Region'),
  ),
];

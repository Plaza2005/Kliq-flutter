import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';

/// Studio & creator tools.
///
/// PRODUCT REQUIREMENT — upload hub: the Studio "Upload" button opens
/// /studio/upload, a hub listing every part of the app content can go to
/// (Posts, Reels, KliqTube, Stories, Live, Marketplace, KliqStream). Each
/// tab NAVIGATES to that module's own independent studio page (e.g. the
/// KliqTube tab goes to /studio/kliqtube — KliqTube Studio) instead of
/// uploading in place.
final studioRoutes = <RouteBase>[
  GoRoute(
    path: '/studio',
    builder: (c, s) => const PlaceholderPage(title: 'Studio'),
  ),
  GoRoute(
    path: '/studio/upload',
    builder: (c, s) => const PlaceholderPage(title: 'Upload Hub'),
  ),
  GoRoute(
    path: '/studio/posts',
    builder: (c, s) => const PlaceholderPage(title: 'Posts Studio'),
  ),
  GoRoute(
    path: '/studio/reels',
    builder: (c, s) => const PlaceholderPage(title: 'Reels Studio'),
  ),
  GoRoute(
    path: '/studio/kliqtube',
    builder: (c, s) => const PlaceholderPage(title: 'KliqTube Studio'),
  ),
  GoRoute(
    path: '/studio/stories',
    builder: (c, s) => const PlaceholderPage(title: 'Stories Studio'),
  ),
  GoRoute(
    path: '/studio/live',
    builder: (c, s) => const PlaceholderPage(title: 'Live Studio'),
  ),
  GoRoute(
    path: '/studio/marketplace',
    builder: (c, s) => const PlaceholderPage(title: 'Marketplace Studio'),
  ),
  GoRoute(
    path: '/studio/kliqstream',
    builder: (c, s) => const PlaceholderPage(title: 'KliqStream Studio'),
  ),
  GoRoute(
    path: '/amplify',
    builder: (c, s) => const PlaceholderPage(title: 'Amplify'),
  ),
  GoRoute(
    path: '/analytics',
    builder: (c, s) => const PlaceholderPage(title: 'Analytics'),
  ),
];

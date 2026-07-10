import 'package:go_router/go_router.dart';

import '../../features/studio/amplify_analytics_pages.dart';
import '../../features/studio/channel_studios.dart';
import '../../features/studio/module_studios.dart';
import '../../features/studio/studio_home_page.dart';
import '../../features/studio/upload_hub_page.dart';

/// Studio & creator tools.
///
/// The Upload button in Studio opens /studio/upload (the Upload Hub), which
/// lists every publishable part of the app; each entry NAVIGATES to that
/// module's own independent studio page where the actual upload happens.
final studioRoutes = <RouteBase>[
  GoRoute(path: '/studio', builder: (c, s) => const StudioHomePage()),
  GoRoute(
      path: '/studio/upload', builder: (c, s) => const UploadHubPage()),
  GoRoute(
      path: '/studio/posts', builder: (c, s) => const PostsStudioPage()),
  GoRoute(
      path: '/studio/reels', builder: (c, s) => const ReelsStudioPage()),
  GoRoute(
      path: '/studio/kliqtube',
      builder: (c, s) => const KliqTubeStudioPage()),
  GoRoute(
      path: '/studio/stories',
      builder: (c, s) => const StoriesStudioPage()),
  GoRoute(
      path: '/studio/live', builder: (c, s) => const LiveStudioPage()),
  GoRoute(
      path: '/studio/marketplace',
      builder: (c, s) => const MarketplaceStudioPage()),
  GoRoute(
      path: '/studio/kliqstream',
      builder: (c, s) => const KliqStreamStudioPage()),
  GoRoute(path: '/amplify', builder: (c, s) => const AmplifyPage()),
  GoRoute(path: '/analytics', builder: (c, s) => const AnalyticsPage()),
];

import 'package:go_router/go_router.dart';

import '../../features/studio/module_studios.dart';

/// Content creation flows: Post, Reel, Story, Live.
final studioRoutes = <RouteBase>[
  GoRoute(
      path: '/studio/posts', builder: (c, s) => const PostsStudioPage()),
  GoRoute(
      path: '/studio/reels', builder: (c, s) => const ReelsStudioPage()),
  GoRoute(
      path: '/studio/stories',
      builder: (c, s) => const StoriesStudioPage()),
  GoRoute(
      path: '/studio/live', builder: (c, s) => const LiveStudioPage()),
];

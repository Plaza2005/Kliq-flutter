import 'package:go_router/go_router.dart';

import '../../features/discover/search_page.dart';
import '../../features/discover/sounds_page.dart';
import '../../features/reels/reels_page.dart';

/// Explore/search and sounds surfaces. (The Reels *tab* lives in the main shell
/// at index 3, registered in app_router.dart. `/reel/:id` is a full-screen
/// viewer opened when tapping a reel from Explore.)
final discoverRoutes = <RouteBase>[
  GoRoute(path: '/search', builder: (c, s) => const SearchPage()),
  GoRoute(path: '/sounds', builder: (c, s) => const SoundsPage()),
  GoRoute(
    path: '/reel/:id',
    builder: (c, s) => ReelsPage(startId: s.pathParameters['id']),
  ),
];

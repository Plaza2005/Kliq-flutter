import 'package:go_router/go_router.dart';

import '../../features/discover/search_page.dart';
import '../../features/discover/sounds_page.dart';

/// Explore/search and sounds surfaces. (Reels lives in the main shell as the
/// index-3 tab, registered in app_router.dart.)
final discoverRoutes = <RouteBase>[
  GoRoute(path: '/search', builder: (c, s) => const SearchPage()),
  GoRoute(path: '/sounds', builder: (c, s) => const SoundsPage()),
];

import 'package:go_router/go_router.dart';

import '../../features/discover/search_page.dart';
import '../../features/discover/sounds_page.dart';
import '../../features/kliqstream/kliqstream_pages.dart';
import '../../features/kliqtube/kliqtube_pages.dart';
import '../../features/reels/reels_page.dart';

/// Explore/search, reels, KliqTube and KliqStream surfaces.
final discoverRoutes = <RouteBase>[
  GoRoute(path: '/search', builder: (c, s) => const SearchPage()),
  GoRoute(path: '/reels', builder: (c, s) => const ReelsPage()),
  GoRoute(
    path: '/kliqtube/watch/:id',
    builder: (c, s) =>
        KliqTubeWatchPage(videoId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/kliqtube/channel/:id',
    builder: (c, s) =>
        KliqTubeChannelPage(channelId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/kliqtube/playlists',
    builder: (c, s) => const KliqTubePlaylistsPage(),
  ),
  GoRoute(path: '/kliqstream', builder: (c, s) => const KliqStreamPage()),
  GoRoute(
    path: '/kliqstream/mylist',
    builder: (c, s) => const KliqStreamMyListPage(),
  ),
  GoRoute(
    path: '/kliqstream/show/:id',
    builder: (c, s) =>
        KliqStreamShowPage(showId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/kliqstream/watch/:id',
    builder: (c, s) => KliqStreamWatchPage(
      episodeId: s.pathParameters['id']!,
      showId: s.uri.queryParameters['show'],
    ),
  ),
  GoRoute(path: '/sounds', builder: (c, s) => const SoundsPage()),
];

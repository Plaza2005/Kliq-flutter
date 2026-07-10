import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';

/// Explore/search, reels, KliqTube and KliqStream surfaces.
/// Owned by the discovery/video feature team.
final discoverRoutes = <RouteBase>[
  GoRoute(
    path: '/search',
    builder: (c, s) => const PlaceholderPage(title: 'Search'),
  ),
  GoRoute(
    path: '/reels',
    builder: (c, s) => const PlaceholderPage(title: 'Reels'),
  ),
  GoRoute(
    path: '/kliqtube/watch/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'KliqTube', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/kliqtube/channel/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Channel', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/kliqtube/playlists',
    builder: (c, s) => const PlaceholderPage(title: 'Playlists'),
  ),
  GoRoute(
    path: '/kliqstream',
    builder: (c, s) => const PlaceholderPage(title: 'KliqStream'),
  ),
  GoRoute(
    path: '/kliqstream/mylist',
    builder: (c, s) => const PlaceholderPage(title: 'My List'),
  ),
  GoRoute(
    path: '/kliqstream/show/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Show', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/kliqstream/watch/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Now Playing', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/sounds',
    builder: (c, s) => const PlaceholderPage(title: 'Sounds'),
  ),
];

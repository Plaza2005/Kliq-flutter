import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';

/// Live streaming surfaces. Owned by the live streaming feature team.
final liveRoutes = <RouteBase>[
  GoRoute(
    path: '/live',
    builder: (c, s) => const PlaceholderPage(title: 'Live Now'),
  ),
  GoRoute(
    path: '/go-live',
    builder: (c, s) => const PlaceholderPage(title: 'Go Live'),
  ),
  GoRoute(
    path: '/live/:id',
    builder: (c, s) => PlaceholderPage(
        title: 'Live Stream', subtitle: s.pathParameters['id']),
  ),
];

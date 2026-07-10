import 'package:go_router/go_router.dart';

import '../../features/live/go_live_page.dart';
import '../../features/live/live_list_page.dart';
import '../../features/live/live_viewer_page.dart';

/// Live streaming surfaces.
final liveRoutes = <RouteBase>[
  GoRoute(path: '/live', builder: (c, s) => const LiveListPage()),
  GoRoute(path: '/go-live', builder: (c, s) => const GoLivePage()),
  GoRoute(
    path: '/live/:id',
    builder: (c, s) => LiveViewerPage(streamId: s.pathParameters['id']!),
  ),
];

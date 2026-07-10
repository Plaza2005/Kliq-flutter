import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';

/// Feed, stories, posts, profile, social-graph and messaging surfaces
/// reachable from Home. Owned by the auth/feed/profile feature team.
final homeRoutes = <RouteBase>[
  GoRoute(
    path: '/post/:id',
    builder: (c, s) =>
        PlaceholderPage(title: 'Post', subtitle: s.pathParameters['id']),
  ),
  GoRoute(
    path: '/story/:userId',
    builder: (c, s) => PlaceholderPage(
        title: 'Story', subtitle: s.pathParameters['userId']),
  ),
  GoRoute(
    path: '/hashtag/:tag',
    builder: (c, s) =>
        PlaceholderPage(title: '#${s.pathParameters['tag']}'),
  ),
  GoRoute(
    path: '/user/:username',
    builder: (c, s) => PlaceholderPage(
        title: '@${s.pathParameters['username']}'),
  ),
  GoRoute(
    path: '/edit-profile',
    builder: (c, s) => const PlaceholderPage(title: 'Edit Profile'),
  ),
  GoRoute(
    path: '/friends',
    builder: (c, s) => const PlaceholderPage(title: 'Friends'),
  ),
  GoRoute(
    path: '/saved',
    builder: (c, s) => const PlaceholderPage(title: 'Saved Posts'),
  ),
  GoRoute(
    path: '/notifications',
    builder: (c, s) => const PlaceholderPage(title: 'Notifications'),
  ),
];

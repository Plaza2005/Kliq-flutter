import 'package:go_router/go_router.dart';

import '../../features/home/misc_pages.dart';
import '../../features/home/post_detail_page.dart';
import '../../features/home/story_viewer_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/social/contacts_page.dart';

/// Feed, stories, posts, profile and social-graph surfaces.
final homeRoutes = <RouteBase>[
  GoRoute(
    path: '/post/:id',
    builder: (c, s) => PostDetailPage(postId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/story/:userId',
    builder: (c, s) =>
        StoryViewerPage(initialUserId: s.pathParameters['userId']!),
  ),
  GoRoute(
    path: '/hashtag/:tag',
    builder: (c, s) => HashtagPage(tag: s.pathParameters['tag']!),
  ),
  GoRoute(
    path: '/user/:username',
    builder: (c, s) => ProfilePage(username: s.pathParameters['username']),
  ),
  GoRoute(
    path: '/edit-profile',
    builder: (c, s) => const EditProfilePage(),
  ),
  GoRoute(path: '/friends', builder: (c, s) => const FriendsPage()),
  GoRoute(path: '/contacts', builder: (c, s) => const ContactsPage()),
  GoRoute(path: '/saved', builder: (c, s) => const SavedPostsPage()),
  GoRoute(
      path: '/notifications', builder: (c, s) => const NotificationsPage()),
];

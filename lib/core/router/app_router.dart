import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';
import '../../features/discover/explore_page.dart';
import '../../features/home/home_feed_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/reels/reels_page.dart';
import '../../features/studio/create_page.dart';
import '../../features/shell/app_shell.dart';
import '../session.dart';
import 'routes_auth.dart';
import 'routes_discover.dart';
import 'routes_home.dart';
import 'routes_live.dart';
import 'routes_social.dart';
import 'routes_studio.dart';

/// Assembles the app router. Feature teams edit their own routes_*.dart
/// file; this file should rarely need to change.
GoRouter buildRouter(Session session) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      final onAuth = authRoutes.any((r) =>
          r is GoRoute && path.startsWith(r.path.split('/:').first));

      // Gate the app behind auth.
      if (!session.isAuthed && !session.isRestoring) {
        return onAuth ? null : '/login';
      }
      if (session.isAuthed) {
        // First-time users must complete onboarding before entering the app.
        final user = session.user;
        final onboarded = user?['isOnboarded'] == true ||
            user?['onboardingComplete'] == true;
        if (!onboarded && !onAuth) return '/onboarding';
        if (path == '/login' || path == '/register') return '/home';
      }
      return null;
    },
    routes: [
      ...authRoutes,

      // ── Main shell: bottom tabs / side rail ──────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (c, s) => const HomeFeedPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/explore',
              builder: (c, s) => const ExplorePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/create',
              builder: (c, s) => const CreatePage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/reels',
              builder: (c, s) => const ReelsPage(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (c, s) => const ProfilePage(),
            ),
          ]),
        ],
      ),

      // ── Full-screen feature routes ───────────────────────────────────────
      ...homeRoutes,
      ...discoverRoutes,
      ...liveRoutes,
      ...studioRoutes,
      ...socialRoutes,
    ],
    errorBuilder: (c, s) => PlaceholderPage(
        title: 'Page not found', subtitle: s.uri.toString()),
  );
}

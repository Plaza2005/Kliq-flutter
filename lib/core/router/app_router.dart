import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';
import '../../features/entry/entry_page.dart';
import '../../features/shell/app_shell.dart';
import '../app_mode.dart';
import '../session.dart';
import 'routes_auth.dart';
import 'routes_discover.dart';
import 'routes_home.dart';
import 'routes_live.dart';
import 'routes_social.dart';
import 'routes_studio.dart';

/// Assembles the app router. Feature teams edit their own routes_*.dart
/// file; this file should rarely need to change.
GoRouter buildRouter(AppModeController mode, Session session) {
  return GoRouter(
    initialLocation: '/entry',
    refreshListenable: Listenable.merge([mode, session]),
    redirect: (context, state) {
      final path = state.uri.path;
      final onEntry = path == '/entry';
      final onAuth = authRoutes.any((r) =>
          r is GoRoute && path.startsWith(r.path.split('/:').first));

      // No mode chosen yet -> entry screen (the Demo button lives there).
      if (!mode.isChosen) return onEntry ? null : '/entry';

      // Demo mode is always "signed in".
      if (mode.isDemo) return (onEntry || onAuth) ? '/home' : null;

      // Live mode: gate the app behind auth.
      if (!session.isAuthed && !session.isRestoring) {
        return (onEntry || onAuth) ? null : '/login';
      }
      if (session.isAuthed && (onEntry || path == '/login' || path == '/register')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/entry', builder: (c, s) => const EntryPage()),
      ...authRoutes,

      // ── Main shell: bottom tabs / side rail ──────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (c, s) => const PlaceholderPage(
                  title: 'Home',
                  subtitle: 'Feed with stories — under construction'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/explore',
              builder: (c, s) => const PlaceholderPage(title: 'Explore'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/create',
              builder: (c, s) => const PlaceholderPage(title: 'Create'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/kliqtube',
              builder: (c, s) => const PlaceholderPage(title: 'KliqTube'),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (c, s) => const PlaceholderPage(title: 'Profile'),
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

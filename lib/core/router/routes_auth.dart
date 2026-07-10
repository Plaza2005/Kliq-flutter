import 'package:go_router/go_router.dart';

import '../../features/common/placeholder_page.dart';

/// Auth & onboarding routes. Owned by the auth/feed/profile feature team —
/// replace the placeholder builders with real pages.
final authRoutes = <RouteBase>[
  GoRoute(
    path: '/login',
    builder: (c, s) => const PlaceholderPage(title: 'Sign In'),
  ),
  GoRoute(
    path: '/register',
    builder: (c, s) => const PlaceholderPage(title: 'Create Account'),
  ),
  GoRoute(
    path: '/forgot-password',
    builder: (c, s) => const PlaceholderPage(title: 'Forgot Password'),
  ),
  GoRoute(
    path: '/reset-password',
    builder: (c, s) => const PlaceholderPage(title: 'Reset Password'),
  ),
  GoRoute(
    path: '/verify-email',
    builder: (c, s) => const PlaceholderPage(title: 'Verify Email'),
  ),
  GoRoute(
    path: '/onboarding',
    builder: (c, s) => const PlaceholderPage(title: 'Onboarding'),
  ),
];

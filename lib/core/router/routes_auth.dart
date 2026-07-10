import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/onboarding_page.dart';
import '../../features/auth/password_pages.dart';
import '../../features/auth/register_page.dart';

/// Auth & onboarding routes.
final authRoutes = <RouteBase>[
  GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
  GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
  GoRoute(
      path: '/forgot-password',
      builder: (c, s) => const ForgotPasswordPage()),
  GoRoute(
    path: '/reset-password',
    builder: (c, s) =>
        ResetPasswordPage(token: s.uri.queryParameters['token']),
  ),
  GoRoute(path: '/verify-email', builder: (c, s) => const VerifyEmailPage()),
  GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingPage()),
];

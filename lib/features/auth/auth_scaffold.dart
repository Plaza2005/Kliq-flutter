import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Turns raw API/network errors into a message a user can act on, instead of
/// dumping a server "Internal Server Error" string on an auth screen.
String friendlyAuthError(Object e) {
  final s = e.toString().replaceFirst('Exception: ', '');
  final lower = s.toLowerCase();
  if (lower.contains('internal server error') || lower.contains('500')) {
    return 'Something went wrong on our end. Please try again in a moment.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('timeout')) {
    return "Can't reach the server. Check your connection and try again.";
  }
  if (lower.contains('sign_in_failed') ||
      lower.contains('apiexception: 10') ||
      lower.contains('clientid') ||
      lower.contains('id token')) {
    return "Google sign-in isn't set up yet. Use email/username for now.";
  }
  return s;
}

/// Shared centered-card layout for all auth screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: KliqWordmark(size: 44)),
                    const SizedBox(height: 8),
                    if (title != null)
                      Center(
                        child: Text(title!,
                            style: const TextStyle(
                                color: KliqColors.textSecondary,
                                fontSize: 15)),
                      ),
                    const SizedBox(height: 28),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }
}

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(message!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: KliqColors.danger, fontSize: 13)),
    );
  }
}

/// "or" divider used between the primary auth button and the social buttons.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: KliqColors.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or',
                style: TextStyle(color: KliqColors.textMuted, fontSize: 12)),
          ),
          Expanded(child: Divider(color: KliqColors.border)),
        ],
      ),
    );
  }
}

/// "Continue with Google" button. Wired to [onPressed] (Session.googleSignIn);
/// only functions once a Google OAuth Client ID is configured — see
/// GOOGLE_SIGNIN_SETUP.md.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black54),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google "G" wordmark stand-in (blue G) — replace with the
                // official multicolour asset if you add one to assets/.
                const Text('G',
                    style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontWeight: FontWeight.w800,
                        fontSize: 18)),
                const SizedBox(width: 10),
                const Text('Continue with Google',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }
}

class AuthButton extends StatelessWidget {
  const AuthButton(
      {super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: KliqColors.gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

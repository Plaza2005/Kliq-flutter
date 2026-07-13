import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.post('/auth/forgot-password',
          body: {'email': _email.text.trim()});
      if (!mounted) return;
      // Hand off to a dedicated confirmation page.
      context.go('/forgot-password/sent', extra: _email.text.trim());
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Reset your password',
      children: [
        const Text(
          'Enter the email linked to your account and we will send '
          'you a reset link.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KliqColors.textSecondary),
        ),
        const SizedBox(height: 20),
        AuthField(
          controller: _email,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        AuthError(_error),
        AuthButton(label: 'Send Reset Link', busy: _busy, onPressed: _submit),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Back to Sign In',
              style: TextStyle(color: KliqColors.textMuted)),
        ),
      ],
    );
  }
}

/// Separate confirmation page shown after a reset link is requested.
class ResetLinkSentPage extends StatelessWidget {
  const ResetLinkSentPage({super.key, this.email});
  final String? email;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Check your email',
      children: [
        const Icon(Icons.mark_email_read_outlined,
            size: 56, color: KliqColors.success),
        const SizedBox(height: 18),
        Text(
          email == null || email!.isEmpty
              ? 'If an account exists for that email, a password reset link is '
                  'on its way. Open it to choose a new password.'
              : 'If an account exists for $email, a password reset link is on '
                  'its way. Open it to choose a new password.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: KliqColors.textSecondary),
        ),
        const SizedBox(height: 24),
        AuthButton(
            label: 'Back to Sign In', onPressed: () => context.go('/login')),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => context.go('/forgot-password'),
          child: const Text('Use a different email',
              style: TextStyle(color: KliqColors.textMuted)),
        ),
      ],
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.token});
  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) _token.text = widget.token!;
  }

  Future<void> _submit() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.post('/auth/reset-password',
          body: {'token': _token.text.trim(), 'password': _password.text});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated — sign in with your new password')));
      context.go('/login');
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choose a new password',
      children: [
        if (widget.token == null)
          AuthField(controller: _token, hint: 'Reset code from your email'),
        AuthField(controller: _password, hint: 'New password', obscure: true),
        AuthField(
            controller: _confirm, hint: 'Confirm new password', obscure: true),
        AuthError(_error),
        AuthButton(label: 'Update Password', busy: _busy, onPressed: _submit),
      ],
    );
  }
}

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify your email',
      children: [
        const Icon(Icons.mark_email_unread_outlined,
            size: 48, color: KliqColors.cyan),
        const SizedBox(height: 16),
        const Text(
          'We sent a verification link to your email address. '
          'Open it to activate your account, then sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KliqColors.textSecondary),
        ),
        const SizedBox(height: 20),
        AuthButton(
            label: 'Go to Sign In', onPressed: () => context.go('/login')),
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Api.instance.post('/auth/resend-verification');
              messenger.showSnackBar(const SnackBar(
                  content: Text('Verification email re-sent')));
            } catch (e) {
              messenger.showSnackBar(
                  SnackBar(content: Text('Could not resend: $e')));
            }
          },
          child: const Text('Resend email',
              style: TextStyle(color: KliqColors.textMuted)),
        ),
      ],
    );
  }
}

/// In-app "Change password" screen (reached from Settings). Verifies the
/// current password server-side and sets a new one.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _next.text.isEmpty) {
      setState(() => _error = 'Fill in every field');
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await Api.instance.post('/auth/change-password', body: {
        'currentPassword': _current.text,
        'newPassword': _next.text,
      });
      messenger.showSnackBar(
          const SnackBar(content: Text('Password changed')));
      navigator.pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AuthField(
              controller: _current,
              hint: 'Current password',
              obscure: true),
          AuthField(controller: _next, hint: 'New password', obscure: true),
          AuthField(
              controller: _confirm,
              hint: 'Confirm new password',
              obscure: true),
          AuthError(_error),
          AuthButton(
              label: 'Update password', busy: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

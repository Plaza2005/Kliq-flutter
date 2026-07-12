import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email or username and password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().login(_identifier.text.trim(), _password.text);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _busy = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await context.read<Session>().googleSignIn();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _googleBusy = false;
        _error = friendlyAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      children: [
        AuthField(
          controller: _identifier,
          hint: 'Email or username',
          keyboardType: TextInputType.text,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
        ),
        AuthField(
          controller: _password,
          hint: 'Password',
          obscure: true,
          autofillHints: const [AutofillHints.password],
        ),
        AuthError(_error),
        AuthButton(label: 'Sign In', busy: _busy, onPressed: _submit),
        const AuthDivider(),
        GoogleButton(busy: _googleBusy, onPressed: _google),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => context.push('/forgot-password'),
          child: const Text('Forgot password?',
              style: TextStyle(color: KliqColors.textSecondary)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Don't have an account? ",
                style: TextStyle(color: KliqColors.textSecondary)),
            GestureDetector(
              onTap: () => context.go('/register'),
              child: const Text('Sign up',
                  style: TextStyle(
                      color: KliqColors.cyan, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

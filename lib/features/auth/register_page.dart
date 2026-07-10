import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import 'auth_scaffold.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final username = _username.text.trim().toLowerCase();
    if (email.isEmpty || username.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Fill in every field');
      return;
    }
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
      await context
          .read<Session>()
          .register(email, _password.text, username);
      if (mounted) context.go('/onboarding');
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
      title: 'Join KLIQ',
      children: [
        AuthField(
          controller: _email,
          hint: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        AuthField(controller: _username, hint: 'Username'),
        AuthField(controller: _password, hint: 'Password', obscure: true),
        AuthField(
            controller: _confirm, hint: 'Confirm password', obscure: true),
        AuthError(_error),
        AuthButton(label: 'Create Account', busy: _busy, onPressed: _submit),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already have an account? ',
                style: TextStyle(color: KliqColors.textSecondary)),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: const Text('Sign in',
                  style: TextStyle(
                      color: KliqColors.cyan, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';

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

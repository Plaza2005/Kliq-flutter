import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_mode.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

/// First screen of the app. The user picks how to run KLIQ:
///  - "Try Demo" — Firebase & Supabase stay OFF, the whole app flows on
///    seeded in-memory data.
///  - "Sign In / Create Account" — live mode against the real backends.
class EntryPage extends StatefulWidget {
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  bool _busy = false;

  Future<void> _choose(AppMode mode) async {
    setState(() => _busy = true);
    final modeController = context.read<AppModeController>();
    final session = context.read<Session>();
    await modeController.choose(mode);
    await session.boot();
    if (!mounted) return;
    if (mode == AppMode.demo) {
      context.go('/home');
    } else {
      context.go(session.isAuthed ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF000000), Color(0xFF0B1020), Color(0xFF1A0B1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Center(child: KliqWordmark(size: 64)),
                    const SizedBox(height: 12),
                    const Text(
                      'Create. Connect. Get paid.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: KliqColors.textSecondary, fontSize: 16),
                    ),
                    const Spacer(),
                    if (_busy)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // ── Demo mode ────────────────────────────────────
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: KliqColors.gradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => _choose(AppMode.demo),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Try Demo',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Explore the full app offline — no account, '
                        'Firebase & Supabase disabled.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: KliqColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      // ── Live mode ────────────────────────────────────
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KliqColors.textPrimary,
                          side: const BorderSide(color: KliqColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _choose(AppMode.live),
                        icon: const Icon(Icons.login),
                        label: const Text('Sign In / Create Account'),
                      ),
                    ],
                    const SizedBox(height: 32),
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

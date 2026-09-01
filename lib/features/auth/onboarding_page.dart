import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// 5-step onboarding wizard (mirrors prot_3's Onboarding.tsx):
/// 1 profile photo · 2 bio · 3 interests · 4 follow suggestions · 5 done.
/// Every step can be skipped; completing all steps earns the
/// "Founding Creator" badge.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pager = PageController();
  final _bio = TextEditingController();
  int _step = 0;
  String? _avatarUrl;
  final _interests = <String>{};
  final _followed = <String>{};
  List<Map<String, dynamic>> _suggestions = [];
  bool _skippedAny = false;
  bool _finishing = false;

  static const _interestOptions = [
    'Music', 'Fashion', 'Food', 'Sport', 'Wildlife', 'Tech',
    'Art', 'Travel', 'Comedy', 'Business', 'Beauty', 'Gaming',
  ];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _pager.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final data = await Api.instance.get('/users/suggestions');
      if (mounted) setState(() => _suggestions = asMapList(data, key: 'users'));
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 800);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final res = await Api.instance.upload(
          '/upload', MultipartFile.fromBytes(bytes, filename: picked.name));
      if (res is Map && res['url'] != null) {
        setState(() => _avatarUrl = res['url'].toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _next({bool skipped = false}) {
    if (skipped) _skippedAny = true;
    if (_step == 4) {
      _finish();
      return;
    }
    _pager.nextPage(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final session = context.read<Session>();
    final router = GoRouter.of(context);
    try {
      final patch = <String, dynamic>{
        if (_avatarUrl != null) 'avatarUrl': _avatarUrl,
        if (_bio.text.trim().isNotEmpty) 'bio': _bio.text.trim(),
        'isOnboarded': true,
      };
      await Api.instance.patch('/auth/me', body: patch);
      await Api.instance.post('/users/onboarding', body: {
        'interests': _interests.toList(),
        'completedAll': !_skippedAny,
      }).catchError((_) => null);
      session.updateUser({...patch, 'onboardingComplete': true});
    } catch (_) {
      // Onboarding must never block entry into the app: even if persisting
      // fails, mark the session as onboarded locally so the router guard
      // does not trap the user here. The server flag stays false, so
      // onboarding simply re-runs on the next login.
      session.updateUser(
          {'isOnboarded': true, 'onboardingComplete': true});
    }
    router.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: List.generate(
            5,
            (i) => Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: i <= _step ? KliqColors.storyRing : null,
                  color: i <= _step ? null : KliqColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_step < 4)
            TextButton(
              onPressed: () => _next(skipped: true),
              child: const Text('Skip',
                  style: TextStyle(color: KliqColors.textMuted)),
            ),
        ],
      ),
      body: PageView(
        controller: _pager,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _step = i),
        children: [
          _stepShell(
            icon: Icons.account_circle_outlined,
            title: 'Add a profile photo',
            subtitle: 'Help people recognise you on KLIQ.',
            child: Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: KliqColors.storyRing,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: _avatarUrl != null
                        ? NetImg(_avatarUrl)
                        : const ColoredBox(
                            color: KliqColors.surfaceElevated,
                            child: Icon(Icons.add_a_photo_outlined,
                                size: 40, color: KliqColors.textMuted),
                          ),
                  ),
                ),
              ),
            ),
          ),
          _stepShell(
            icon: Icons.edit_outlined,
            title: 'Tell us about yourself',
            subtitle: 'A short bio appears on your profile.',
            child: TextField(
              controller: _bio,
              maxLines: 4,
              maxLength: 160,
              decoration:
                  const InputDecoration(hintText: 'Creating content about…'),
            ),
          ),
          _stepShell(
            icon: Icons.interests_outlined,
            title: 'Pick your interests',
            subtitle: 'We use these to personalise your feed.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in _interestOptions)
                  FilterChip(
                    label: Text(tag),
                    selected: _interests.contains(tag),
                    selectedColor: KliqColors.cyan.withValues(alpha: 0.25),
                    checkmarkColor: KliqColors.cyan,
                    onSelected: (v) => setState(
                        () => v ? _interests.add(tag) : _interests.remove(tag)),
                  ),
              ],
            ),
          ),
          _stepShell(
            icon: Icons.people_outline,
            title: 'Follow creators',
            subtitle: 'Your feed starts with the people you follow.',
            child: _suggestions.isEmpty
                ? const Text('No suggestions right now.',
                    style: TextStyle(color: KliqColors.textMuted))
                : Column(
                    children: [
                      for (final u in _suggestions.take(6))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: KliqAvatar(u['avatarUrl']?.toString()),
                          title: Text(
                              u['displayName']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('@${u['username']}',
                              style: const TextStyle(
                                  color: KliqColors.textMuted)),
                          trailing: OutlinedButton(
                            onPressed: () async {
                              final id = u['id'].toString();
                              setState(() => _followed.contains(id)
                                  ? _followed.remove(id)
                                  : _followed.add(id));
                              Api.instance
                                  .post('/users/$id/follow')
                                  .catchError((_) => null);
                            },
                            child: Text(
                                _followed.contains(u['id'].toString())
                                    ? 'Following'
                                    : 'Follow'),
                          ),
                        ),
                    ],
                  ),
          ),
          _stepShell(
            icon: Icons.celebration_outlined,
            title: 'You are all set!',
            subtitle: _skippedAny
                ? 'Welcome to KLIQ — start exploring.'
                : 'You completed every step — the Founding Creator badge '
                    'is yours. Welcome to KLIQ!',
            child: const Center(child: KliqWordmark(size: 40)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DecoratedBox(
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
              onPressed: _finishing ? null : _next,
              child: Text(_step == 4 ? 'Enter KLIQ' : 'Continue',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepShell({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (b) => KliqColors.gradient.createShader(b),
                child: Icon(icon, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KliqColors.textSecondary)),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';
import '../home/feed_models.dart';

/// Studio home — the creator command centre: performance summary, the
/// Upload button (opens the Upload Hub), Amplify & Analytics shortcuts and
/// a manageable grid of published content.
class StudioHomePage extends StatefulWidget {
  const StudioHomePage({super.key});

  @override
  State<StudioHomePage> createState() => _StudioHomePageState();
}

class _StudioHomePageState extends State<StudioHomePage> {
  List<Post> _content = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = context.read<Session>().userId;
      final data = await Api.instance.get('/users/$id/posts');
      if (!mounted) return;
      setState(() {
        _content = parsePostList(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(Post p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KliqColors.surface,
        title: const Text('Delete this post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: KliqColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _content.removeWhere((x) => x.id == p.id));
    Api.instance.delete('/posts/${p.id}').catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user ?? {};
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Studio', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Analytics',
              onPressed: () => context.push('/analytics')),
          IconButton(
              icon: const Icon(Icons.rocket_launch_outlined),
              tooltip: 'Amplify',
              onPressed: () => context.push('/amplify')),
        ],
      ),
      body: RefreshIndicator(
        color: KliqColors.cyan,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Performance summary ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    KliqColors.cyan.withValues(alpha: 0.12),
                    KliqColors.pink.withValues(alpha: 0.12)
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KliqColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(formatCount(
                          (user['followerCount'] as num? ?? 0).toInt()),
                      'Followers'),
                  _stat(formatCount((user['postCount'] as num? ?? 0).toInt()),
                      'Content'),
                  _stat('${_content.length}', 'Published'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Upload button → Upload Hub ──────────────────────────────
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
                onPressed: () => context.push('/studio/upload'),
                icon: const Icon(Icons.upload),
                label: const Text('Upload',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Choose a destination — every format has its own studio.',
                style:
                    TextStyle(color: KliqColors.textMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('Your content',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/analytics'),
                  child: const Text('View analytics',
                      style:
                          TextStyle(color: KliqColors.cyan, fontSize: 13)),
                ),
              ],
            ),
            if (_loading)
              const CenterSpinner()
            else if (_content.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: EmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: 'Nothing published yet',
                    subtitle: 'Hit Upload to create your first piece'),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: _content.length,
                itemBuilder: (context, i) {
                  final p = _content[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/post/${p.id}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: p.isText
                              ? Container(
                                  color: KliqColors.surfaceElevated,
                                  padding: const EdgeInsets.all(8),
                                  child: Text(p.body,
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          const TextStyle(fontSize: 10.5)),
                                )
                              : NetImg(p.mediaUrls.first),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _delete(p),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(Icons.delete_outline, size: 15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: KliqColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

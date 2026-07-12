import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../common/kliq_video.dart';
import '../discover/discover_common.dart';

/// TikTok-style full-screen vertical reels swiper. One video plays at a
/// time; double-tap to like; overlay shows author/caption/sound and the
/// like/comment/share rail.
class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final _pager = PageController();
  List<Map<String, dynamic>> _reels = [];
  bool _loading = true;
  String? _error;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    dataEpoch.addListener(_onDataEpoch);
    _load();
  }

  @override
  void dispose() {
    dataEpoch.removeListener(_onDataEpoch);
    _pager.dispose();
    super.dispose();
  }

  void _onDataEpoch() {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/reels');
      var reels = asMapList(data, key: 'reels');
      if (reels.isEmpty) {
        reels = asMapList(await Api.instance.get('/posts/reels'));
      }
      if (!mounted) return;
      setState(() {
        _reels = reels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLike(int index) async {
    final r = _reels[index];
    final liked = pickBool(r, ['isLiked', 'liked']);
    setState(() {
      r['isLiked'] = !liked;
      r['likeCount'] = pickInt(r, ['likeCount']) + (liked ? -1 : 1);
    });
    Api.instance.post('/posts/${r['id']}/like').catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const CenterSpinner()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _reels.isEmpty
                  ? const EmptyState(
                      icon: Icons.movie_outlined, title: 'No reels yet')
                  : Stack(
                      children: [
                        PageView.builder(
                          controller: _pager,
                          scrollDirection: Axis.vertical,
                          itemCount: _reels.length,
                          onPageChanged: (i) =>
                              setState(() => _current = i),
                          itemBuilder: (context, i) => _ReelItem(
                            key: ValueKey(_reels[i]['id']),
                            reel: _reels[i],
                            active: i == _current,
                            onLike: () => _toggleLike(i),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: BackButton(
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/home'),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ReelItem extends StatelessWidget {
  const _ReelItem(
      {super.key, required this.reel, required this.active, required this.onLike});

  final Map<String, dynamic> reel;
  final bool active;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final author = authorOf(reel);
    final videoUrl = pickStr(reel, ['videoUrl', 'mediaUrl']);
    final liked = pickBool(reel, ['isLiked', 'liked']);

    return GestureDetector(
      onDoubleTap: onLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (active && videoUrl.isNotEmpty)
            KliqVideo(
                url: videoUrl,
                controlsEnabled: false,
                loop: true,
                fit: BoxFit.cover)
          else
            NetImg(pickStr(reel, ['thumbnailUrl'])),
          // Bottom scrim
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Author + caption + sound
          Positioned(
            left: 14,
            right: 80,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () =>
                      context.push('/user/${author['username']}'),
                  child: Row(
                    children: [
                      KliqAvatar(author['avatarUrl'], radius: 16),
                      const SizedBox(width: 8),
                      Text('@${author['username']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(pickStr(reel, ['caption', 'body']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.music_note, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          pickStr(reel, ['soundName'],
                              fallback: 'Original audio'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: KliqColors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action rail
          Positioned(
            right: 10,
            bottom: 40,
            child: Column(
              children: [
                _railButton(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? KliqColors.live : Colors.white,
                  label: fmtCount(pickInt(reel, ['likeCount'])),
                  onTap: onLike,
                ),
                const SizedBox(height: 18),
                _railButton(
                  icon: Icons.mode_comment_outlined,
                  label: fmtCount(pickInt(reel, ['commentCount'])),
                  onTap: () => context.push('/post/${reel['id']}'),
                ),
                const SizedBox(height: 18),
                _railButton(
                  icon: Icons.share_outlined,
                  label: fmtCount(pickInt(reel, ['shareCount'])),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _railButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 30, color: color, shadows: const [
            Shadow(blurRadius: 8, color: Colors.black54)
          ]),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

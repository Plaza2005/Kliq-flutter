import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../common/kliq_video.dart';
import '../discover/discover_common.dart';
import '../live/live_list_page.dart';
import '../shell/app_shell.dart';

/// Reels branch index in the bottom nav (see AppShell).
const _reelsBranchIndex = 3;

/// TikTok-style full-screen vertical reels swiper. One video plays at a time;
/// tap to pause/resume, double-tap to like. When opened from Explore with a
/// [startId] it jumps to that reel and shows a back button.
class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key, this.startId});

  /// When set (e.g. opened from Explore), jump to this reel on load.
  final String? startId;

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final _pager = PageController();
  List<Map<String, dynamic>> _reels = [];
  bool _loading = true;
  String? _error;
  int _current = 0;

  /// Whether this reels view is the visible surface. When false (another tab is
  /// selected, or a route is pushed over it) the active video is paused so it
  /// doesn't play in the background.
  late bool _visible;

  // ── View / completion tracking (feeds the TikTok completion-rate signal) ──
  Timer? _completeTimer;
  final _viewed = <String>{};
  final _completed = <String>{};

  /// for_you | following | live
  String _tab = 'for_you';

  bool get _isPushed => widget.startId != null;

  @override
  void initState() {
    super.initState();
    _visible = _computeVisible();
    dataEpoch.addListener(_onDataEpoch);
    shellTabIndex.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    dataEpoch.removeListener(_onDataEpoch);
    shellTabIndex.removeListener(_onTabChanged);
    _completeTimer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  bool _computeVisible() =>
      _isPushed || shellTabIndex.value == _reelsBranchIndex;

  void _onTabChanged() {
    final v = _computeVisible();
    if (v != _visible && mounted) setState(() => _visible = v);
  }

  /// Report a view for the active reel, and — if the viewer lingers ~3s —
  /// a completed view. Completion rate is the dominant ranking signal.
  void _trackActive(int index) {
    _completeTimer?.cancel();
    if (index < 0 || index >= _reels.length) return;
    final id = _reels[index]['id']?.toString();
    if (id == null) return;
    if (_viewed.add(id)) {
      Api.instance.post('/posts/$id/view').catchError((_) => null);
    }
    _completeTimer = Timer(const Duration(seconds: 3), () {
      if (_completed.add(id)) {
        Api.instance.post('/posts/$id/complete').catchError((_) => null);
      }
    });
  }

  void _onDataEpoch() {
    if (!mounted || _tab == 'live') return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _switchTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      if (tab != 'live') {
        _loading = true;
        _error = null;
        _current = 0;
      }
    });
    if (tab != 'live') _load();
  }

  /// Pull fresh reels for the current tab and jump back to the top.
  void _refresh() {
    _viewed.clear();
    _completed.clear();
    setState(() {
      _loading = true;
      _error = null;
      _current = 0;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/posts/reels', query: {'tab': _tab});
      final reels = asMapList(data, key: 'posts');
      if (!mounted) return;
      // If launched at a specific reel (from Explore), start there.
      var start = 0;
      if (widget.startId != null) {
        final idx =
            reels.indexWhere((r) => r['id']?.toString() == widget.startId);
        if (idx > 0) start = idx;
      }
      setState(() {
        _reels = reels;
        _loading = false;
        _current = start;
      });
      if (_pager.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _pager.hasClients ? _pager.jumpToPage(start) : null);
      }
      if (_reels.isNotEmpty) _trackActive(_current);
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
      body: Stack(
        children: [
          Positioned.fill(child: _content()),
          // TikTok-style top tabs: For You · Following · Live
          SafeArea(
            child: Align(alignment: Alignment.topCenter, child: _topTabs()),
          ),
          // Refresh (top-right)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6, top: 2),
                child: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh,
                      color: Colors.white, shadows: [
                    Shadow(blurRadius: 8, color: Colors.black87)
                  ]),
                  onPressed: _refresh,
                ),
              ),
            ),
          ),
          // Back (top-left) when opened from Explore
          if (_isPushed)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: BackButton(
                    color: Colors.white,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_tab == 'live') return const LiveStreamsView();
    if (_loading) return const CenterSpinner();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_reels.isEmpty) {
      return EmptyState(
        icon: Icons.movie_creation_outlined,
        title: _tab == 'following'
            ? 'No reels from people you follow yet'
            : 'No reels yet',
        actionLabel: 'Create reel',
        onAction: () => context.go('/create'),
      );
    }
    return PageView.builder(
      controller: _pager,
      scrollDirection: Axis.vertical,
      itemCount: _reels.length,
      onPageChanged: (i) {
        setState(() => _current = i);
        _trackActive(i);
      },
      itemBuilder: (context, i) => _ReelItem(
        key: ValueKey(_reels[i]['id']),
        reel: _reels[i],
        active: i == _current,
        visible: _visible,
        onLike: () => _toggleLike(i),
      ),
    );
  }

  Widget _topTabs() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabButton('For You', 'for_you'),
          _dot(),
          _tabButton('Following', 'following'),
          _dot(),
          _tabButton('Live', 'live', isLive: true),
        ],
      ),
    );
  }

  Widget _dot() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text('·', style: TextStyle(color: Colors.white38, fontSize: 15)),
      );

  Widget _tabButton(String label, String value, {bool isLive = false}) {
    final active = _tab == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTab(value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLive)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(Icons.sensors,
                      size: 15,
                      color: active ? KliqColors.live : Colors.white70),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white60,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 2.5,
            width: 22,
            decoration: BoxDecoration(
              gradient: active ? KliqColors.storyRing : null,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  const _ReelItem({
    super.key,
    required this.reel,
    required this.active,
    required this.visible,
    required this.onLike,
  });

  final Map<String, dynamic> reel;
  final bool active;
  final bool visible;
  final VoidCallback onLike;

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  bool _manualPaused = false;

  @override
  void didUpdateWidget(_ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset the manual-pause when this reel is no longer the current one.
    if (oldWidget.active && !widget.active && _manualPaused) {
      _manualPaused = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final author = authorOf(reel);
    final videoUrl = pickStr(reel, ['videoUrl', 'mediaUrl']);
    final liked = pickBool(reel, ['isLiked', 'liked']);
    final hasVideo = videoUrl.isNotEmpty;
    final playing = widget.active && widget.visible && !_manualPaused;

    return GestureDetector(
      onTap: () {
        if (widget.active && hasVideo) {
          setState(() => _manualPaused = !_manualPaused);
        }
      },
      onDoubleTap: widget.onLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.active && hasVideo)
            KliqVideo(
              url: videoUrl,
              controlsEnabled: false,
              loop: true,
              fit: BoxFit.cover,
              paused: !playing,
            )
          else
            NetImg(pickStr(reel, ['thumbnailUrl'])),
          // Pause indicator
          if (widget.active && hasVideo && _manualPaused)
            const Center(
              child: Icon(Icons.play_arrow,
                  size: 82,
                  color: Colors.white70,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black87)]),
            ),
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
                  onTap: () => context.push('/user/${author['username']}'),
                  child: Row(
                    children: [
                      KliqAvatar(author['avatarUrl'], radius: 16),
                      const SizedBox(width: 8),
                      Text('@${author['username']}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
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
                  context,
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? KliqColors.live : Colors.white,
                  label: fmtCount(pickInt(reel, ['likeCount'])),
                  onTap: widget.onLike,
                ),
                const SizedBox(height: 18),
                _railButton(
                  context,
                  icon: Icons.mode_comment_outlined,
                  label: fmtCount(pickInt(reel, ['commentCount'])),
                  onTap: () => context.push('/post/${reel['id']}'),
                ),
                const SizedBox(height: 18),
                _railButton(
                  context,
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

  Widget _railButton(
    BuildContext context, {
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../discover/discover_common.dart' hide timeAgo;
import 'feed_models.dart';

/// Full-screen story viewer: progress bars, tap right/left to move between
/// slides, auto-advance, swipe down to close. Starts at [initialUserId]'s
/// group and continues through the rest of the story feed.
class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({super.key, required this.initialUserId});

  final String initialUserId;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  List<StoryGroup> _groups = [];
  int _group = 0;
  int _slide = 0;
  bool _loading = true;
  Timer? _timer;
  double _progress = 0;

  static const _slideDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/stories/feed');
      final groups = (data is List ? data : const [])
          .whereType<Map>()
          .map((e) => StoryGroup.fromJson(e.cast<String, dynamic>()))
          .where((g) => g.slides.isNotEmpty)
          .toList();
      final start = groups.indexWhere((g) =>
          g.userId == widget.initialUserId ||
          g.author.username == widget.initialUserId);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _group = start < 0 ? 0 : start;
        _loading = false;
      });
      if (groups.isNotEmpty) _startTimer();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _progress = 0;
    _markViewed();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        _progress += 50 / _slideDuration.inMilliseconds;
        if (_progress >= 1) _next();
      });
    });
  }

  void _markViewed() {
    final g = _groups[_group];
    final s = g.slides[_slide];
    Api.instance.post('/stories/${s.id}/view').catchError((_) => null);
  }

  void _next() {
    final g = _groups[_group];
    if (_slide < g.slides.length - 1) {
      setState(() => _slide++);
      _startTimer();
    } else if (_group < _groups.length - 1) {
      setState(() {
        _group++;
        _slide = 0;
      });
      _startTimer();
    } else {
      _close();
    }
  }

  void _prev() {
    if (_slide > 0) {
      setState(() => _slide--);
      _startTimer();
    } else if (_group > 0) {
      setState(() {
        _group--;
        _slide = _groups[_group].slides.length - 1;
      });
      _startTimer();
    }
  }

  void _close() {
    _timer?.cancel();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: Colors.black, body: CenterSpinner());
    }
    if (_groups.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black),
        body: const EmptyState(
            icon: Icons.auto_stories_outlined, title: 'No stories right now'),
      );
    }

    final group = _groups[_group];
    final slide = group.slides[_slide];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          final w = MediaQuery.sizeOf(context).width;
          d.globalPosition.dx < w / 3 ? _prev() : _next();
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) _close();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetImg(slide.mediaUrl, fit: BoxFit.contain),
            // Top scrim + progress + author row
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: List.generate(
                            group.slides.length,
                            (i) => Expanded(
                              child: Container(
                                height: 2.5,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5),
                                child: LinearProgressIndicator(
                                  value: i < _slide
                                      ? 1
                                      : (i == _slide ? _progress : 0),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.3),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            KliqAvatar(group.author.avatarUrl, radius: 16),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context
                                  .push('/user/${group.author.username}'),
                              child: Text(group.author.username,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Text(timeAgo(slide.createdAt),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _close,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (slide.body != null && slide.body!.isNotEmpty)
              Positioned(
                bottom: 48,
                left: 24,
                right: 24,
                child: Text(
                  slide.body!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black)]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

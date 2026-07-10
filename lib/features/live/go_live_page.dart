import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import 'frame_broadcaster.dart';
import 'live_widgets.dart';

/// Broadcaster surface: camera preview, stream setup (title/category),
/// then live frame broadcasting over the WS relay with chat, gifts and
/// viewer count coming back in realtime.
class GoLivePage extends StatefulWidget {
  const GoLivePage({super.key});

  @override
  State<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<GoLivePage> {
  final _title = TextEditingController();
  String _category = 'Entertainment';
  static const _categories = [
    'Entertainment', 'Music', 'Sports', 'Food', 'Gaming', 'Talk', 'Education'
  ];

  FrameBroadcaster? _broadcaster;
  CameraController? _camera;
  String? _cameraError;
  bool _initializing = true;
  bool _frontCamera = true;

  bool _isLive = false;
  String? _streamId;
  Duration _elapsed = Duration.zero;
  Timer? _clock;
  int _viewers = 0;
  int _earnedCoins = 0;
  final _chat = <LiveChatMessage>[];
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _endStreamSilently();
    _wsSub?.cancel();
    _clock?.cancel();
    _broadcaster?.dispose();
    _title.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (!FrameBroadcaster.platformSupported) {
      setState(() {
        _initializing = false;
        _cameraError =
            'Broadcasting is not supported on this platform yet. '
            'You can still watch live streams.';
      });
      return;
    }
    try {
      _broadcaster = FrameBroadcaster(streamId: '');
      final cam = await _broadcaster!.init(frontCamera: _frontCamera);
      if (!mounted) return;
      setState(() {
        _camera = cam;
        _initializing = false;
        _cameraError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _cameraError = 'Camera unavailable: $e';
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_isLive) return;
    _frontCamera = !_frontCamera;
    setState(() => _initializing = true);
    await _broadcaster?.dispose();
    await _initCamera();
  }

  Future<void> _goLive() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your stream a title')));
      return;
    }
    try {
      final res = await Api.instance.post('/live/start', body: {
        'title': _title.text.trim(),
        'category': _category,
      });
      final streamId = res['streamId']?.toString();
      if (streamId == null) throw Exception('No streamId returned');

      // Rebind the broadcaster to the real stream id and start pushing.
      final b = FrameBroadcaster(streamId: streamId)
        ..controller = _broadcaster!.controller;
      _broadcaster = b;

      WsService.instance.connect();
      _wsSub = WsService.instance.events.listen(_onWsEvent);
      WsService.instance.subscribeToStream(streamId);
      b.start();
      WakelockPlus.enable();

      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });

      setState(() {
        _isLive = true;
        _streamId = streamId;
        _chat.add(LiveChatMessage(
            username: 'KLIQ', body: 'You are live! 🎉'));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not start stream: $e')));
      }
    }
  }

  void _onWsEvent(Map<String, dynamic> e) {
    if (e['streamId'] != null && e['streamId'] != _streamId) return;
    switch (e['type']) {
      case 'live:chat':
        setState(() => _chat.add(LiveChatMessage(
            username: e['fromUsername']?.toString() ?? 'viewer',
            body: e['body']?.toString() ?? '')));
      case 'live:gift':
        final sender = e['sender'] is Map
            ? (e['sender']['username']?.toString() ?? 'someone')
            : 'someone';
        setState(() {
          _earnedCoins += (e['coins'] as num?)?.toInt() ?? 0;
          _chat.add(LiveChatMessage(
              username: sender,
              body: 'sent a ${e['giftType']} 🎁',
              isGift: true));
        });
      case 'live:viewers':
        setState(
            () => _viewers = (e['viewerCount'] as num?)?.toInt() ?? _viewers);
    }
  }

  Future<void> _endStreamSilently() async {
    if (!_isLive) return;
    _broadcaster?.stop();
    if (_streamId != null) {
      WsService.instance.unsubscribeFromStream(_streamId!);
    }
    Api.instance.post('/live/end').catchError((_) => null);
  }

  Future<void> _endStream() async {
    final earned = _earnedCoins;
    final duration = _elapsed;
    await _endStreamSilently();
    _clock?.cancel();
    WakelockPlus.disable();
    if (!mounted) return;
    setState(() => _isLive = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KliqColors.surface,
        title: const Text('Stream ended'),
        content: Text(
            'You were live for ${duration.inMinutes}m ${duration.inSeconds % 60}s '
            'and earned $earned coins in gifts.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done')),
        ],
      ),
    );
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview (or the error/empty state)
            if (_initializing)
              const Center(
                  child: CircularProgressIndicator(color: KliqColors.cyan))
            else if (_cameraError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined,
                          size: 52, color: KliqColors.textMuted),
                      const SizedBox(height: 14),
                      Text(_cameraError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: KliqColors.textSecondary)),
                      const SizedBox(height: 18),
                      OutlinedButton(
                        onPressed: () => context.push('/live'),
                        child: const Text('Browse live streams'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_camera != null)
              Center(child: CameraPreview(_camera!)),

            // Top bar
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      if (_isLive) {
                        await _endStream();
                      } else if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  const Spacer(),
                  if (_isLive) ...[
                    LiveBadgeRow(viewerCount: _viewers),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(_fmtElapsed(),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ] else if (_camera != null)
                    IconButton(
                      icon: const Icon(Icons.cameraswitch_outlined),
                      onPressed: _flipCamera,
                    ),
                ],
              ),
            ),

            // Pre-live setup card
            if (!_isLive && _cameraError == null && !_initializing)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _title,
                        decoration: const InputDecoration(
                            hintText: 'Stream title'),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final c in _categories)
                              Padding(
                                padding:
                                    const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c,
                                      style: const TextStyle(
                                          fontSize: 12)),
                                  selected: _category == c,
                                  selectedColor: KliqColors.cyan
                                      .withValues(alpha: 0.3),
                                  onSelected: (_) =>
                                      setState(() => _category = c),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: KliqColors.gradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          onPressed: _goLive,
                          icon: const Icon(Icons.sensors),
                          label: const Text('Go Live',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Live chat overlay
            if (_isLive)
              Positioned(
                left: 12,
                bottom: 16,
                width: 280,
                height: 260,
                child: LiveChatFeed(messages: _chat),
              ),
            if (_isLive)
              Positioned(
                right: 12,
                bottom: 20,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.diamond,
                              size: 14, color: KliqColors.cyan),
                          const SizedBox(width: 4),
                          Text('$_earnedCoins',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'endLive',
                      backgroundColor: KliqColors.live,
                      onPressed: _endStream,
                      child: const Icon(Icons.stop),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtElapsed() {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}


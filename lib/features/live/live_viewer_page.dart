import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../discover/discover_common.dart';
import 'live_widgets.dart';

/// Viewer surface: subscribes to the stream over WS & Agora RTC engine, renders the stream,
/// and overlays realtime chat, gifts and the viewer count.
class LiveViewerPage extends StatefulWidget {
  const LiveViewerPage({super.key, required this.streamId});

  final String streamId;

  @override
  State<LiveViewerPage> createState() => _LiveViewerPageState();
}

class _LiveViewerPageState extends State<LiveViewerPage> {
  Map<String, dynamic>? _stream;
  bool _loading = true;
  Uint8List? _frame;
  bool _receivingVideo = false;
  bool _subscribed = false;
  bool _loggedFirstFrame = false;
  int _viewers = 0;
  final _chat = <LiveChatMessage>[];
  final _bursts = <Widget>[];
  final _chatInput = TextEditingController();
  StreamSubscription? _wsSub;
  RtcEngine? _agoraEngine;
  int? _hostUid;

  @override
  void initState() {
    super.initState();
    _join();
    _joinAgoraChannel();
  }

  @override
  void dispose() {
    WsService.instance.unsubscribeFromStream(widget.streamId);
    _wsSub?.cancel();
    _chatInput.dispose();
    _leaveAgoraChannel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _joinAgoraChannel() async {
    final channelName = 'live_${widget.streamId}';
    try {
      final res = await Api.instance
          .post('/agora/rtc-token', body: {'channel': channelName});
      final data = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      final token = data['token']?.toString();
      final appId = data['appId']?.toString();
      if (token == null || appId == null || token.isEmpty || appId.isEmpty) {
        return;
      }

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) {
            setState(() {
              _hostUid = remoteUid;
              _receivingVideo = true;
            });
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted && _hostUid == remoteUid) {
            setState(() => _hostUid = null);
          }
        },
      ));

      await engine.enableVideo();
      await engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      if (mounted) setState(() => _agoraEngine = engine);
    } catch (e) {
      debugPrint('[LiveViewerPage] Agora RTC join error: $e');
    }
  }

  Future<void> _leaveAgoraChannel() async {
    final engine = _agoraEngine;
    _agoraEngine = null;
    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
  }

  Future<void> _join() async {
    // Subscribe first so the cached/live frame starts flowing immediately;
    // metadata and the view-count POST happen in parallel, not blocking it.
    WsService.instance.connect();
    _wsSub = WsService.instance.events.listen(_onWsEvent);
    WsService.instance.subscribeToStream(widget.streamId);
    _subscribed = true;
    WakelockPlus.enable();
    if (mounted) setState(() => _loading = false);

    // Stream metadata comes from the live list.
    Api.instance.get('/live/streams').then((streams) {
      if (!mounted) return;
      final list = asMapList(streams, key: 'streams');
      final stream = list.where((x) => x['id'] == widget.streamId).firstOrNull;
      setState(() {
        _stream = stream;
        _viewers = pickInt(_stream ?? {}, ['viewerCount']);
      });
    }).catchError((_) => null);

    Api.instance
        .post('/live/${widget.streamId}/view')
        .then((r) {
          if (r is Map && r['viewerCount'] != null && mounted) {
            setState(
                () => _viewers = (r['viewerCount'] as num).toInt());
          }
        })
        .catchError((_) => null);
  }

  void _onWsEvent(Map<String, dynamic> e) {
    if (e['streamId'] != null && e['streamId'] != widget.streamId) return;
    switch (e['type']) {
      case 'live:chunk':
        final chunk = e['chunk'];
        if (chunk is String && chunk.isNotEmpty) {
          try {
            final bytes = base64Decode(chunk);
            if (!_loggedFirstFrame) {
              _loggedFirstFrame = true;
              debugPrint(
                  '[viewer] first live:chunk received for ${widget.streamId} (${chunk.length} b64 chars)');
            }
            setState(() {
              _frame = bytes;
              _receivingVideo = true;
            });
          } catch (err) {
            // Non-JPEG chunk (e.g. a webm broadcaster) — keep the poster.
            debugPrint('[viewer] live:chunk decode failed: $err');
          }
        }
      case 'live:chat':
        setState(() => _chat.add(LiveChatMessage(
            username: e['fromUsername']?.toString() ?? 'viewer',
            body: e['body']?.toString() ?? '')));
      case 'live:gift':
        final sender = e['sender'] is Map
            ? (e['sender']['username']?.toString() ?? 'someone')
            : 'someone';
        final gift = e['giftType']?.toString() ?? 'rose';
        setState(() {
          _chat.add(LiveChatMessage(
              username: sender, body: 'sent a $gift 🎁', isGift: true));
          _bursts.add(GiftBurst(
              key: UniqueKey(), gift: gift, from: sender));
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _bursts.isNotEmpty) {
            setState(() => _bursts.removeAt(0));
          }
        });
      case 'live:viewers':
        setState(
            () => _viewers = (e['viewerCount'] as num?)?.toInt() ?? _viewers);
    }
  }

  void _sendChat() {
    final body = _chatInput.text.trim();
    if (body.isEmpty) return;
    final username = context.read<Session>().username;
    WsService.instance.sendLiveChat(widget.streamId, body, username);
    // The server does not echo the sender's own chat back.
    setState(() =>
        _chat.add(LiveChatMessage(username: username, body: body)));
    _chatInput.clear();
  }

  Future<void> _sendGift() async {
    final gift = await showGiftSheet(context);
    if (gift == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance
          .post('/live/${widget.streamId}/gift', body: {'giftType': gift});
      messenger.showSnackBar(SnackBar(content: Text('You sent a $gift!')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gift failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = authorOf(_stream ?? {});
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _loading
            ? const CenterSpinner()
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Video: Agora RTC view, fallback incoming frame, else stream poster.
                  if (_agoraEngine != null && _hostUid != null)
                    AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: _agoraEngine!,
                        canvas: VideoCanvas(uid: _hostUid),
                        connection: RtcConnection(channelId: 'live_${widget.streamId}'),
                      ),
                    )
                  else if (_frame != null)
                    Image.memory(_frame!,
                        gaplessPlayback: true, fit: BoxFit.contain)
                  else
                    Stack(fit: StackFit.expand, children: [
                      NetImg(pickStr(_stream ?? {}, ['thumbnailUrl'])),
                      Container(
                          color: Colors.black.withValues(alpha: 0.35)),
                      if (!_receivingVideo)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  color: KliqColors.cyan),
                              const SizedBox(height: 12),
                              Text(
                                  _subscribed
                                      ? 'Waiting for video…'
                                      : 'Connecting to stream…',
                                  style: const TextStyle(
                                      color:
                                          KliqColors.textSecondary)),
                            ],
                          ),
                        ),
                    ]),

                  // Top bar: host info + live badge + close
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 8,
                    child: Row(
                      children: [
                        KliqAvatar(host['avatarUrl'], radius: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(host['displayName'] ?? 'Live',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5)),
                              Text(
                                  pickStr(_stream ?? {}, ['title']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color:
                                          KliqColors.textSecondary,
                                      fontSize: 11.5)),
                            ],
                          ),
                        ),
                        LiveBadgeRow(viewerCount: _viewers),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/live'),
                        ),
                      ],
                    ),
                  ),

                  // Gift bursts
                  Positioned(
                    top: 90,
                    left: 0,
                    right: 0,
                    child: Column(children: _bursts),
                  ),

                  // Chat overlay + input
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            height: 220,
                            width: 280,
                            child: LiveChatFeed(messages: _chat)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chatInput,
                                onSubmitted: (_) => _sendChat(),
                                decoration: InputDecoration(
                                  hintText: 'Say something…',
                                  fillColor: Colors.black
                                      .withValues(alpha: 0.5),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send,
                                  color: KliqColors.cyan),
                              onPressed: _sendChat,
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.card_giftcard,
                                  color: KliqColors.pink),
                              onPressed: _sendGift,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

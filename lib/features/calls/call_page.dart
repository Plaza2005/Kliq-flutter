import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../discover/discover_common.dart' show KliqAvatar;

/// 1:1 voice/video call screen.
///
/// Two ways in (see routes_social.dart's `/call/:id` and the callers in
/// messaging_pages.dart / incoming_call_overlay.dart):
///  - Caller: pushed right after `POST /calls` succeeds, [isCaller]=true,
///    [startAccepted]=false — shows a "Calling…" screen and joins the Agora
///    channel only once a `call:accept` WS event arrives.
///  - Callee: pushed by [IncomingCallOverlay] right after it already called
///    `POST /calls/:id/accept`, [isCaller]=false, [startAccepted]=true —
///    joins the Agora channel immediately.
///
/// Both sides listen for `call:reject`/`call:end` the same way ChatPage
/// listens for `message:deleted`/`message:reaction` (see
/// messaging_pages.dart's `_onWsEvent`) — a switch over `WsService.instance
/// .events` filtered by this call's id.
class CallPage extends StatefulWidget {
  const CallPage({
    super.key,
    required this.callId,
    required this.channel,
    required this.callType,
    required this.otherUser,
    required this.isCaller,
    this.startAccepted = false,
  });

  final String callId;
  final String channel;

  /// 'voice' | 'video'.
  final String callType;
  final Map<String, dynamic> otherUser;
  final bool isCaller;
  final bool startAccepted;

  @override
  State<CallPage> createState() => _CallPageState();
}

enum _CallStage { ringing, connecting, active, ended }

class _CallPageState extends State<CallPage> {
  RtcEngine? _engine;
  StreamSubscription? _wsSub;
  Timer? _durationTimer;

  late _CallStage _stage =
      widget.startAccepted ? _CallStage.connecting : _CallStage.ringing;
  bool _muted = false;
  bool _speakerOn = true;
  bool _cameraOff = false;
  int? _remoteUid;
  Duration _duration = Duration.zero;
  String? _error;
  bool _ending = false;

  bool get _isVideo => widget.callType == 'video';

  @override
  void initState() {
    super.initState();
    _wsSub = WsService.instance.events.listen(_onWsEvent);
    if (widget.startAccepted) _joinChannel();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _durationTimer?.cancel();
    _leaveAndRelease();
    super.dispose();
  }

  void _onWsEvent(Map<String, dynamic> e) {
    if (e['callId']?.toString() != widget.callId) return;
    switch (e['type']) {
      case 'call:accept':
        if (widget.isCaller && _stage == _CallStage.ringing) {
          setState(() => _stage = _CallStage.connecting);
          _joinChannel();
        }
        break;
      case 'call:reject':
        _endedRemotely('Call declined');
        break;
      case 'call:end':
        _endedRemotely('Call ended');
        break;
    }
  }

  void _endedRemotely(String message) {
    if (!mounted || _stage == _CallStage.ended) return;
    _durationTimer?.cancel();
    setState(() => _stage = _CallStage.ended);
    _leaveAndRelease();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _joinChannel() async {
    try {
      final res = await Api.instance
          .post('/agora/rtc-token', body: {'channel': widget.channel});
      final data = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      final token = data['token']?.toString();
      final appId = data['appId']?.toString();
      if (token == null || appId == null || token.isEmpty || appId.isEmpty) {
        throw Exception('No token returned');
      }

      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!mounted) return;
          setState(() => _stage = _CallStage.active);
          _durationTimer?.cancel();
          _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _duration += const Duration(seconds: 1));
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted && _remoteUid == remoteUid) setState(() => _remoteUid = null);
        },
        onError: (err, msg) {
          if (mounted) setState(() => _error = msg);
        },
      ));

      if (_isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      } else {
        await engine.disableVideo();
        await engine.enableAudio();
      }
      _speakerOn = _isVideo;
      await engine.setEnableSpeakerphone(_speakerOn);

      await engine.joinChannel(
        token: token,
        channelId: widget.channel,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      if (mounted) setState(() => _engine = engine);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not join call: $e');
    }
  }

  Future<void> _leaveAndRelease() async {
    final engine = _engine;
    _engine = null;
    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    try {
      await Api.instance.post('/calls/${widget.callId}/end');
    } catch (_) {}
    await _leaveAndRelease();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
    if (mounted) setState(() {});
  }

  Future<void> _toggleCamera() async {
    _cameraOff = !_cameraOff;
    await _engine?.muteLocalVideoStream(_cameraOff);
    if (mounted) setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await _engine?.setEnableSpeakerphone(_speakerOn);
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get _otherName {
    final name = widget.otherUser['displayName']?.toString();
    if (name != null && name.isNotEmpty) return name;
    return widget.otherUser['username']?.toString() ?? 'User';
  }

  String get _statusLabel {
    switch (_stage) {
      case _CallStage.ringing:
        return widget.isCaller ? 'Calling…' : 'Incoming call…';
      case _CallStage.connecting:
        return 'Connecting…';
      case _CallStage.active:
        return _formatDuration(_duration);
      case _CallStage.ended:
        return 'Call ended';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              if (_isVideo && _engine != null) _videoLayer() else _audioLayer(),
              if (!_isVideo || _engine == null)
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: _errorBanner(),
                ),
              if (_isVideo && _engine != null)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(_statusLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                      _errorBanner(),
                    ],
                  ),
                ),
              Positioned(left: 0, right: 0, bottom: 32, child: _controls()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Text(_error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: KliqColors.danger, fontSize: 12)),
    );
  }

  Widget _audioLayer() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KliqAvatar(widget.otherUser['avatarUrl']?.toString(), radius: 64),
          const SizedBox(height: 24),
          Text(_otherName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_statusLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _videoLayer() {
    final engine = _engine!;
    return Stack(
      children: [
        Positioned.fill(
          child: _remoteUid != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channel),
                  ),
                )
              : Container(
                  color: KliqColors.surfaceElevated,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KliqAvatar(widget.otherUser['avatarUrl']?.toString(), radius: 48),
                        const SizedBox(height: 12),
                        Text(_otherName,
                            style: const TextStyle(color: Colors.white, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
        ),
        Positioned(
          top: 90,
          right: 16,
          width: 110,
          height: 150,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _cameraOff
                ? Container(
                    color: KliqColors.surfaceElevated,
                    child: const Icon(Icons.videocam_off, color: Colors.white54),
                  )
                : AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _controls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlButton(
          icon: _muted ? Icons.mic_off : Icons.mic,
          active: _muted,
          onTap: _engine == null ? null : _toggleMute,
        ),
        const SizedBox(width: 20),
        if (_isVideo)
          _controlButton(
            icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
            active: _cameraOff,
            onTap: _engine == null ? null : _toggleCamera,
          )
        else
          _controlButton(
            icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
            active: !_speakerOn,
            onTap: _engine == null ? null : _toggleSpeaker,
          ),
        if (_isVideo) ...[
          const SizedBox(width: 20),
          _controlButton(
            icon: Icons.cameraswitch,
            active: false,
            onTap: _engine == null ? null : _switchCamera,
          ),
        ],
        const SizedBox(width: 20),
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(color: KliqColors.danger, shape: BoxShape.circle),
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _controlButton(
      {required IconData icon, required bool active, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white70),
      ),
    );
  }
}

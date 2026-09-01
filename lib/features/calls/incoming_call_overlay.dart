import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../discover/discover_common.dart' show KliqAvatar;

/// Global incoming-call banner, mounted once around the whole app (see
/// main.dart's `MaterialApp.router` `builder`). Listens for `call:invite` on
/// the same `WsService.instance.events` stream ChatPage already listens to
/// for `message:deleted`/`message:reaction` (see messaging_pages.dart's
/// `_onWsEvent`), so a call rings no matter which screen is open.
///
/// Takes the app's [GoRouter] directly (rather than resolving it via
/// `GoRouter.of(context)`) because this widget wraps `MaterialApp.router`'s
/// `builder`, whose `context` sits above the Router in the tree.
class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> {
  StreamSubscription? _wsSub;

  /// The pending invite payload straight off the WS event:
  /// { callId, channel, callType, caller: {id, username, displayName, avatarUrl} }.
  Map<String, dynamic>? _invite;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _wsSub = WsService.instance.events.listen(_onWsEvent);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  void _onWsEvent(Map<String, dynamic> e) {
    final type = e['type'];
    if (type == 'call:invite') {
      if (mounted) setState(() => _invite = Map<String, dynamic>.from(e));
      return;
    }
    // The caller hung up before we answered (or another device of ours
    // already handled it) — dismiss the banner either way.
    if ((type == 'call:end' || type == 'call:accept') &&
        _invite != null &&
        e['callId']?.toString() == _invite!['callId']?.toString()) {
      if (mounted) setState(() => _invite = null);
    }
  }

  Future<void> _accept() async {
    final invite = _invite;
    if (invite == null || _responding) return;
    setState(() => _responding = true);
    try {
      await Api.instance.post('/calls/${invite['callId']}/accept');
      if (!mounted) return;
      setState(() {
        _invite = null;
        _responding = false;
      });
      widget.router.push('/call/${invite['callId']}', extra: {
        'channel': invite['channel'],
        'callType': invite['callType'],
        'otherUser': invite['caller'],
        'isCaller': false,
        'startAccepted': true,
      });
    } catch (_) {
      if (mounted) setState(() => _responding = false);
    }
  }

  Future<void> _reject() async {
    final invite = _invite;
    if (invite == null || _responding) return;
    setState(() => _responding = true);
    try {
      await Api.instance.post('/calls/${invite['callId']}/reject');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _invite = null;
        _responding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return Stack(
      children: [
        widget.child,
        if (invite != null) _banner(invite),
      ],
    );
  }

  Widget _banner(Map<String, dynamic> invite) {
    final caller = invite['caller'] is Map
        ? Map<String, dynamic>.from(invite['caller'] as Map)
        : <String, dynamic>{};
    final displayName = caller['displayName']?.toString();
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (caller['username']?.toString() ?? 'Someone');
    final isVideo = invite['callType'] == 'video';

    return Positioned.fill(
      child: Material(
        color: Colors.black87,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KliqAvatar(caller['avatarUrl']?.toString(), radius: 56),
                    const SizedBox(height: 20),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(isVideo ? 'Incoming video call…' : 'Incoming voice call…',
                        style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton(
                      icon: Icons.call_end,
                      color: KliqColors.danger,
                      label: 'Decline',
                      onTap: _responding ? null : _reject,
                    ),
                    _actionButton(
                      icon: isVideo ? Icons.videocam : Icons.call,
                      color: KliqColors.success,
                      label: 'Accept',
                      onTap: _responding ? null : _accept,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback? onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }
}

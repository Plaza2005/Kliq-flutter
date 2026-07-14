import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'config.dart';

/// Global refresh signal: bumped whenever the server announces that the
/// underlying data changed wholesale (e.g. an admin cleared/loaded demo
/// data). Pages listen and re-fetch their content when it ticks.
final dataEpoch = ValueNotifier<int>(0);

/// Realtime service matching the server protocol
/// (`ws://host:4000/ws?token=[jwt]`, JSON messages).
///
/// Message types the server understands:
///   stream:subscribe / stream:unsubscribe  { streamId }
///   stream:chunk                           { streamId, chunk }
///   live:chat                              { streamId, body, fromUsername }
///
/// Events pushed by the server include: connected, live:chunk, live:chat,
/// live:gift, notification, message, ...
///
/// In demo mode nothing connects: [send] is looped through the demo backend,
/// which simulates viewers/chat so live surfaces still flow.
class WsService {
  WsService._();
  static final instance = WsService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnectTimer;
  bool _shouldRun = false;
  final Set<String> _streamSubs = {};

  static const _minReconnectMs = 500;
  static const _maxReconnectMs = 5000;
  int _reconnectDelayMs = _minReconnectMs;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _channel != null;

  void connect() {
    _shouldRun = true;
    _reconnectDelayMs = _minReconnectMs;
    if (_channel != null) return;
    final token = Api.instance.token;
    if (token == null) return;
    _open(token);
  }

  void _open(String token) {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsUrl}?token=$token'),
      );
      _sub = _channel!.stream.listen(
        (raw) {
          try {
            _reconnectDelayMs = _minReconnectMs;
            final msg = jsonDecode(raw as String);
            if (msg is Map<String, dynamic>) {
              _events.add(msg);
              if (msg['type'] == 'admin:demo-data-changed') {
                dataEpoch.value++;
              }
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
      );
      for (final streamId in _streamSubs) {
        send({'type': 'stream:subscribe', 'streamId': streamId});
      }
      debugPrint('[ws] connected');
    } catch (e) {
      debugPrint('[ws] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _channel = null;
    _sub?.cancel();
    _sub = null;
    if (!_shouldRun) return;
    _reconnectTimer?.cancel();
    final delay = _reconnectDelayMs;
    _reconnectDelayMs = (_reconnectDelayMs * 2).clamp(_minReconnectMs, _maxReconnectMs);
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      final token = Api.instance.token;
      if (_shouldRun && token != null) _open(token);
    });
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void subscribeToStream(String streamId) {
    _streamSubs.add(streamId);
    send({'type': 'stream:subscribe', 'streamId': streamId});
  }

  void unsubscribeFromStream(String streamId) {
    _streamSubs.remove(streamId);
    send({'type': 'stream:unsubscribe', 'streamId': streamId});
  }

  void sendStreamChunk(String streamId, String chunkBase64) =>
      send({'type': 'stream:chunk', 'streamId': streamId, 'chunk': chunkBase64});

  void sendLiveChat(String streamId, String body, String fromUsername) => send({
        'type': 'live:chat',
        'streamId': streamId,
        'body': body,
        'fromUsername': fromUsername,
      });

  void disconnect() {
    _shouldRun = false;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

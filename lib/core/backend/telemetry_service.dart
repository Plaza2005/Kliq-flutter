import '../api_client.dart';
import '../ws_service.dart';

/// Telemetry Service for emitting real-time client performance metrics,
/// AdMob ad impression/click events, Agora RTC stream stats, and reel completion metrics.
class TelemetryService {
  TelemetryService._();
  static final instance = TelemetryService._();

  /// Report an AdMob ad impression or click event to the backend.
  Future<void> reportAdEvent({
    required String adType, // 'reel_ad' | 'feed_ad'
    required String eventType, // 'impression' | 'click'
    String? adUnitId,
  }) async {
    final payload = {
      'type': 'telemetry:ad',
      'adType': adType,
      'eventType': eventType,
      'adUnitId': adUnitId ?? 'default_admob_unit',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Emit live over WebSocket if connected
    WsService.instance.sendRaw(payload);

    // Persist via HTTP API telemetry ingestion
    try {
      await Api.instance.post('/admin/telemetry', body: payload);
    } catch (_) {
      // Telemetry failures are non-blocking
    }
  }

  /// Report video reel playback / completion rate metrics.
  Future<void> reportReelMetric({
    required String reelId,
    required double watchDurationSeconds,
    required bool completed,
  }) async {
    final payload = {
      'type': 'telemetry:reel',
      'reelId': reelId,
      'watchDurationSeconds': watchDurationSeconds,
      'completed': completed,
      'timestamp': DateTime.now().toIso8601String(),
    };

    WsService.instance.sendRaw(payload);

    try {
      await Api.instance.post('/admin/telemetry', body: payload);
    } catch (_) {}
  }

  /// Report Agora RTC live stream performance stats.
  Future<void> reportAgoraStreamStats({
    required String streamId,
    required int bitrateKbps,
    required int fps,
    required int packetLossPercent,
  }) async {
    final payload = {
      'type': 'telemetry:agora',
      'streamId': streamId,
      'bitrateKbps': bitrateKbps,
      'fps': fps,
      'packetLossPercent': packetLossPercent,
      'timestamp': DateTime.now().toIso8601String(),
    };

    WsService.instance.sendRaw(payload);
  }
}

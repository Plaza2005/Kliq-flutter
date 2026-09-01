import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/ws_service.dart';

/// Captures low-resolution JPEG frames from the camera and pushes them over
/// the WebSocket as `stream:chunk` messages (the server relays them to every
/// subscriber as `live:chunk`). Viewers decode the base64 JPEG chunks with
/// `Image.memory`, which works on Android, iOS, web and desktop alike.
///
/// - Android/iOS: `startImageStream` (YUV420/BGRA) → downscale → JPEG.
/// - Web: `takePicture()` loop (canvas-backed, cheap) at ~3 fps.
/// - Windows/Linux: the camera plugin has no backend → broadcasting is
///   reported unsupported; those platforms can still watch streams.
class FrameBroadcaster {
  FrameBroadcaster({required this.streamId, this.targetFps = 4});

  final String streamId;
  final int targetFps;

  CameraController? controller;
  Timer? _webTimer;
  bool _busy = false;
  bool _running = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  static bool get platformSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Initialises the camera. Throws with a readable message on failure.
  Future<CameraController> init({bool frontCamera = true}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No camera found on this device');
    final cam = cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (frontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
      orElse: () => cameras.first,
    );
    final ctrl = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          kIsWeb ? ImageFormatGroup.jpeg : ImageFormatGroup.yuv420,
    );
    await ctrl.initialize();
    controller = ctrl;
    return ctrl;
  }

  void start() {
    if (_running || controller == null) return;
    _running = true;
    if (kIsWeb) {
      _webTimer = Timer.periodic(
          Duration(milliseconds: (1000 / targetFps).round()), (_) async {
        if (_busy || !_running) return;
        _busy = true;
        try {
          final shot = await controller!.takePicture();
          final bytes = await shot.readAsBytes();
          _send(bytes);
        } catch (_) {
        } finally {
          _busy = false;
        }
      });
    } else {
      controller!.startImageStream(_onFrame);
    }
  }

  void _onFrame(CameraImage frame) {
    if (!_running || _busy) return;
    final now = DateTime.now();
    if (now.difference(_lastFrame).inMilliseconds < 1000 / targetFps) return;
    _lastFrame = now;
    _busy = true;
    // Convert + encode off the critical path.
    Future(() {
      try {
        final jpeg = _encodeFrame(frame);
        if (jpeg != null) _send(jpeg);
      } catch (_) {
      } finally {
        _busy = false;
      }
    });
  }

  Uint8List? _encodeFrame(CameraImage frame) {
    img.Image? rgb;
    if (frame.format.group == ImageFormatGroup.yuv420) {
      rgb = _yuv420ToImage(frame);
    } else if (frame.format.group == ImageFormatGroup.bgra8888) {
      rgb = img.Image.fromBytes(
        width: frame.width,
        height: frame.height,
        bytes: frame.planes[0].bytes.buffer,
        order: img.ChannelOrder.bgra,
      );
    }
    if (rgb == null) return null;
    // Downscale for bandwidth: ~360px wide keeps chunks ≈15-30 KB.
    final scaled = img.copyResize(rgb, width: 360);
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 60));
  }

  img.Image _yuv420ToImage(CameraImage frame) {
    final w = frame.width, h = frame.height;
    final out = img.Image(width: w, height: h);
    final yPlane = frame.planes[0];
    final uPlane = frame.planes[1];
    final vPlane = frame.planes[2];
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final yv = yPlane.bytes[y * yPlane.bytesPerRow + x];
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
        final u = uPlane.bytes[uvIndex] - 128;
        final v = vPlane.bytes[uvIndex] - 128;
        final r = (yv + 1.402 * v).clamp(0, 255).toInt();
        final g = (yv - 0.344136 * u - 0.714136 * v).clamp(0, 255).toInt();
        final b = (yv + 1.772 * u).clamp(0, 255).toInt();
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  void _send(Uint8List jpegBytes) {
    WsService.instance.sendStreamChunk(streamId, base64Encode(jpegBytes));
  }

  Future<void> stop() async {
    _running = false;
    _webTimer?.cancel();
    _webTimer = null;
    try {
      if (!kIsWeb && (controller?.value.isStreamingImages ?? false)) {
        await controller?.stopImageStream();
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await controller?.dispose();
    controller = null;
  }
}

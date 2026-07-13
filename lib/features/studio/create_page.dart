import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// The Create tab: a full-screen camera capture screen (Snapchat/Instagram
/// Reel style). Top controls, a left tool rail, a capture button, and
/// STORY / REEL / LIVE mode tabs. When the camera isn't available (e.g. web
/// over plain HTTP), it falls back to a gallery picker so Create still works.
class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _flashOn = false;
  bool _busy = false;
  bool _initializing = true;
  String _mode = 'REEL'; // STORY | REEL | LIVE

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() => _initializing = true);
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw Exception('No cameras');
      // Prefer the back camera first.
      _cameraIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back);
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _startController();
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _startController() async {
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _initializing = false;
    });
  }

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    await _camera?.dispose();
    _camera = null;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    try {
      await _startController();
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final cam = _camera;
    if (cam == null) return;
    _flashOn = !_flashOn;
    await cam.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (_mode == 'LIVE') {
      context.push('/go-live');
      return;
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      _pickFromGallery();
      return;
    }
    setState(() => _busy = true);
    try {
      final shot = await cam.takePicture();
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() => _busy = false);
      _openComposer(bytes, shot.name);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not capture: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      _openComposer(bytes, picked.name);
    } catch (e) {
      _snack('Could not open gallery: $e');
    }
  }

  void _openComposer(Uint8List bytes, String filename) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KliqColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _Composer(
        bytes: bytes,
        filename: filename,
        onPosted: () => _snack('Shared 🎉'),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _comingSoon() => _snack('Coming soon');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _viewfinder(),
          // dark top/bottom scrims for control legibility
          const _Scrim(top: true),
          const _Scrim(top: false),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 8),
                _audioPill(),
                Expanded(child: _leftRail()),
                _bottomControls(),
                _modeTabs(),
              ],
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Colors.black38,
              child: Center(
                  child: CircularProgressIndicator(color: KliqColors.cyan)),
            ),
        ],
      ),
    );
  }

  Widget _viewfinder() {
    final cam = _camera;
    if (cam != null && cam.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: cam.value.previewSize?.height ?? 1080,
          height: cam.value.previewSize?.width ?? 1920,
          child: CameraPreview(cam),
        ),
      );
    }
    // Fallback: dark screen with a hint to pick from the gallery.
    return GestureDetector(
      onTap: _pickFromGallery,
      child: Container(
        color: const Color(0xFF0A0A0A),
        alignment: Alignment.center,
        child: _initializing
            ? const CircularProgressIndicator(color: KliqColors.cyan)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.photo_library_outlined,
                      size: 44, color: Colors.white70),
                  SizedBox(height: 10),
                  Text('Camera unavailable\nTap to pick from gallery',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          _circleBtn(Icons.close, onTap: () => context.go('/home')),
          const Spacer(),
          _circleBtn(_flashOn ? Icons.flash_on : Icons.flash_off,
              onTap: _toggleFlash),
          const SizedBox(width: 10),
          _circleBtn(null, label: '1×', onTap: _comingSoon),
          const SizedBox(width: 10),
          _circleBtn(Icons.timer_outlined, onTap: _comingSoon),
          const Spacer(),
          _circleBtn(Icons.settings_outlined, onTap: _comingSoon),
        ],
      ),
    );
  }

  Widget _audioPill() {
    return GestureDetector(
      onTap: _comingSoon,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text('Add audio',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _leftRail() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _railBtn(Icons.music_note),
            _railBtn(Icons.auto_awesome),
            _railBtn(Icons.face_retouching_natural),
            _railBtn(Icons.auto_fix_high),
            _railBtn(Icons.timelapse, label: '15'),
          ],
        ),
      ),
    );
  }

  Widget _railBtn(IconData icon, {String? label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: GestureDetector(
        onTap: _comingSoon,
        child: Column(
          children: [
            Icon(icon,
                size: 26,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]),
            if (label != null)
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gallery
          GestureDetector(
            onTap: _pickFromGallery,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white70, width: 1.5),
                color: Colors.white10,
              ),
              child: const Icon(Icons.photo_library_outlined,
                  size: 20, color: Colors.white),
            ),
          ),
          // Capture button
          GestureDetector(
            onTap: _busy ? null : _capture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _mode == 'LIVE' ? KliqColors.live : Colors.white,
                    width: 5),
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _mode == 'LIVE'
                        ? KliqColors.live
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                  child: _mode == 'LIVE'
                      ? const Icon(Icons.sensors, color: Colors.white)
                      : null,
                ),
              ),
            ),
          ),
          // Flip camera
          GestureDetector(
            onTap: _flip,
            child: const Icon(Icons.flip_camera_ios_outlined,
                size: 34, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _modeTabs() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final m in const ['STORY', 'REEL', 'LIVE'])
            GestureDetector(
              onTap: () {
                setState(() => _mode = m);
                if (m == 'LIVE') context.push('/go-live');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  m,
                  style: TextStyle(
                    color: _mode == m ? Colors.white : Colors.white54,
                    fontWeight:
                        _mode == m ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData? icon, {String? label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 20, color: Colors.white)
            : Text(label ?? '',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Top/bottom gradient scrim so white controls stay legible over the preview.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.top});
  final bool top;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
      child: Container(
        height: top ? 130 : 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Caption + share sheet shown after capturing or picking media.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.bytes,
    required this.filename,
    required this.onPosted,
  });

  final Uint8List bytes;
  final String filename;
  final VoidCallback onPosted;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _caption = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _posting = true);
    final navigator = Navigator.of(context);
    try {
      final up = await Api.instance.upload(
        '/upload',
        MultipartFile.fromBytes(widget.bytes, filename: widget.filename),
      );
      final url = up is Map ? up['url']?.toString() : null;
      await Api.instance.post('/posts', body: {
        'body': _caption.text.trim(),
        if (url != null) 'mediaUrls': [url],
        'mediaType': 'image',
      });
      widget.onPosted();
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(widget.bytes,
                    width: 72, height: 72, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _caption,
                  maxLines: 3,
                  minLines: 1,
                  decoration:
                      const InputDecoration(hintText: 'Write a caption…'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: KliqColors.gradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: _posting ? null : _share,
                child: _posting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Share',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

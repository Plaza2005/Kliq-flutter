import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// A named Instagram-style colour filter (4x5 colour matrix).
class InstaFilter {
  const InstaFilter(this.name, this.matrix);
  final String name;
  final List<double> matrix;
  ColorFilter get filter => ColorFilter.matrix(matrix);
}

/// 10 popular Instagram filters (+ Original). Approximated as colour matrices.
const kFilters = <InstaFilter>[
  InstaFilter('Original', [
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Clarendon', [
    1.2, 0, 0, 0, -18, //
    0, 1.2, 0, 0, -22, //
    0, 0, 1.25, 0, -12, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Gingham', [
    0.95, 0, 0, 0, 20, //
    0, 0.92, 0, 0, 15, //
    0, 0, 0.9, 0, 12, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Juno', [
    1.15, 0, 0, 0, 0, //
    0, 1.06, 0, 0, 0, //
    0, 0, 0.92, 0, 6, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Lark', [
    1.05, 0.05, 0.05, 0, 10, //
    0.05, 1.0, 0.05, 0, 10, //
    0.05, 0.05, 1.0, 0, 15, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Ludwig', [
    1.1, 0.02, 0.02, 0, 4, //
    0.02, 1.0, 0.02, 0, 0, //
    0.02, 0.02, 0.95, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Aden', [
    0.9, 0, 0, 0, 25, //
    0, 0.9, 0, 0, 15, //
    0, 0, 0.95, 0, 22, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Reyes', [
    0.9, 0.1, 0.1, 0, 20, //
    0.1, 0.85, 0.1, 0, 15, //
    0.1, 0.1, 0.8, 0, 10, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Slumber', [
    0.9, 0.08, 0.08, 0, 8, //
    0.08, 0.85, 0.08, 0, 4, //
    0.08, 0.08, 0.82, 0, 4, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Crema', [
    0.95, 0.03, 0.03, 0, 15, //
    0.03, 0.95, 0.03, 0, 15, //
    0.03, 0.03, 1.0, 0, 10, //
    0, 0, 0, 1, 0,
  ]),
  InstaFilter('Moon', [
    0.33, 0.59, 0.11, 0, 0, //
    0.33, 0.59, 0.11, 0, 0, //
    0.33, 0.59, 0.11, 0, 8, //
    0, 0, 0, 1, 0,
  ]),
];

/// The Create tab: a full-screen camera capture screen (Instagram/Reel style)
/// with POST / STORY / REEL / LIVE modes. Photos go through a filter + caption
/// composer; reels record video; live opens the broadcaster. Falls back to a
/// gallery picker when the camera is unavailable (e.g. web over plain HTTP).
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
  bool _recording = false;
  String _mode = 'POST'; // POST | STORY | REEL | LIVE

  static const _modes = ['POST', 'STORY', 'REEL', 'LIVE'];

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
      _cameraIndex =
          _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
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
      enableAudio: true,
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
    if (_cameras.length < 2 || _recording) return;
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

  void _onCapture() {
    switch (_mode) {
      case 'LIVE':
        context.push('/go-live');
        break;
      case 'REEL':
        _recording ? _stopRecording() : _startRecording();
        break;
      default:
        _takePhoto();
    }
  }

  Future<void> _takePhoto() async {
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
      _openPhotoComposer(bytes, shot.name);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Could not capture: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      _pickFromGallery();
      return;
    }
    try {
      await cam.startVideoRecording();
      setState(() => _recording = true);
    } catch (e) {
      _snack('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    final cam = _camera;
    if (cam == null) return;
    setState(() => _busy = true);
    try {
      final file = await cam.stopVideoRecording();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _busy = false;
      });
      _openVideoComposer(bytes, file.name);
    } catch (e) {
      if (mounted) {
        setState(() {
          _recording = false;
          _busy = false;
        });
        _snack('Could not save reel: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      if (_mode == 'REEL') {
        final v = await picker.pickVideo(source: ImageSource.gallery);
        if (v == null) return;
        final bytes = await v.readAsBytes();
        if (mounted) _openVideoComposer(bytes, v.name);
      } else {
        final p =
            await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
        if (p == null) return;
        final bytes = await p.readAsBytes();
        if (mounted) _openPhotoComposer(bytes, p.name);
      }
    } catch (e) {
      _snack('Could not open gallery: $e');
    }
  }

  void _openPhotoComposer(Uint8List bytes, String filename) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KliqColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PhotoComposer(
        bytes: bytes,
        filename: filename,
        isStory: _mode == 'STORY',
        onDone: (msg) => _snack(msg),
      ),
    );
  }

  void _openVideoComposer(Uint8List bytes, String filename) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KliqColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VideoComposer(
        bytes: bytes,
        filename: filename,
        onDone: (msg) => _snack(msg),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
    return GestureDetector(
      onTap: _pickFromGallery,
      child: Container(
        color: const Color(0xFF0A0A0A),
        alignment: Alignment.center,
        child: _initializing
            ? const CircularProgressIndicator(color: KliqColors.cyan)
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
    final isLive = _mode == 'LIVE';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _recording ? null : _pickFromGallery,
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
          GestureDetector(
            onTap: _busy ? null : _onCapture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: (isLive || _recording)
                        ? KliqColors.live
                        : Colors.white,
                    width: 5),
              ),
              child: Center(
                child: _recording
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: KliqColors.live,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLive
                              ? KliqColors.live
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                        child: isLive
                            ? const Icon(Icons.sensors, color: Colors.white)
                            : null,
                      ),
              ),
            ),
          ),
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
          for (final m in _modes)
            GestureDetector(
              onTap: () {
                if (_recording) return;
                setState(() => _mode = m);
                if (m == 'LIVE') context.push('/go-live');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  m,
                  style: TextStyle(
                    color: _mode == m ? Colors.white : Colors.white54,
                    fontWeight:
                        _mode == m ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData? icon,
      {String? label, required VoidCallback onTap}) {
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
        height: top ? 130 : 210,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

/// Photo composer: pick one of the 10 filters, add a caption, and share.
/// The chosen filter is baked into the uploaded image via a RepaintBoundary.
class _PhotoComposer extends StatefulWidget {
  const _PhotoComposer({
    required this.bytes,
    required this.filename,
    required this.isStory,
    required this.onDone,
  });

  final Uint8List bytes;
  final String filename;
  final bool isStory;
  final ValueChanged<String> onDone;

  @override
  State<_PhotoComposer> createState() => _PhotoComposerState();
}

class _PhotoComposerState extends State<_PhotoComposer> {
  final _caption = TextEditingController();
  final _boundaryKey = GlobalKey();
  int _filter = 0;
  bool _posting = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<Uint8List> _renderFiltered() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _share() async {
    setState(() => _posting = true);
    final navigator = Navigator.of(context);
    try {
      // Bake the filter (unless Original) then upload.
      final out =
          _filter == 0 ? widget.bytes : await _renderFiltered();
      final name = _filter == 0 ? widget.filename : 'kliq_${DateTime.now().millisecondsSinceEpoch}.png';
      final up = await Api.instance
          .upload('/upload', MultipartFile.fromBytes(out, filename: name));
      final url = up is Map ? up['url']?.toString() : null;
      if (widget.isStory) {
        await Api.instance.post('/stories', body: {
          'mediaUrl': ?url,
          'mediaType': 'image',
          'body': _caption.text.trim(),
        });
      } else {
        await Api.instance.post('/posts', body: {
          'body': _caption.text.trim(),
          if (url != null) 'mediaUrls': [url],
          'mediaType': 'image',
        });
      }
      widget.onDone(widget.isStory ? 'Story shared 🎉' : 'Post shared 🎉');
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
          left: 14,
          right: 14,
          top: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Filtered preview (this is what gets captured on share).
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: ColorFiltered(
                colorFilter: kFilters[_filter].filter,
                child: Image.memory(widget.bytes,
                    height: 300, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Filter strip.
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final selected = i == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = i),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? KliqColors.cyan
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ColorFiltered(
                            colorFilter: kFilters[i].filter,
                            child: Image.memory(widget.bytes,
                                width: 52, height: 52, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(kFilters[i].name,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? KliqColors.textPrimary
                                : KliqColors.textMuted,
                          )),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _caption,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'Write a caption…'),
          ),
          const SizedBox(height: 14),
          _ShareButton(
            label: widget.isStory ? 'Share to Story' : 'Share',
            busy: _posting,
            onPressed: _share,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Reel composer: caption + share (posts a video, which the server files as a
/// reel).
class _VideoComposer extends StatefulWidget {
  const _VideoComposer({
    required this.bytes,
    required this.filename,
    required this.onDone,
  });

  final Uint8List bytes;
  final String filename;
  final ValueChanged<String> onDone;

  @override
  State<_VideoComposer> createState() => _VideoComposerState();
}

class _VideoComposerState extends State<_VideoComposer> {
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
          '/upload', MultipartFile.fromBytes(widget.bytes, filename: widget.filename));
      final url = up is Map ? up['url']?.toString() : null;
      await Api.instance.post('/posts', body: {
        'body': _caption.text.trim(),
        if (url != null) 'mediaUrls': [url],
        'mediaType': 'video',
      });
      widget.onDone('Reel shared 🎉');
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
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: KliqColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.movie_creation_outlined,
                    color: KliqColors.cyan),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Your reel is ready',
                      style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'Write a caption…'),
          ),
          const SizedBox(height: 14),
          _ShareButton(label: 'Share Reel', busy: _posting, onPressed: _share),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton(
      {required this.label, required this.busy, required this.onPressed});
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: KliqColors.gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton(
          onPressed: busy ? null : onPressed,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

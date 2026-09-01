import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// A sticker saved to the current user's personal library — either uploaded
/// directly, converted from a short video via `POST /stickers/convert`, or
/// long-press-saved from a comment/chat media attachment.
class StickerItem {
  StickerItem({
    required this.id,
    required this.url,
    required this.sourceType,
    required this.createdAt,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final int? width;
  final int? height;
  final String sourceType;
  final DateTime createdAt;

  factory StickerItem.fromJson(Map<String, dynamic> json) => StickerItem(
        id: json['id']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        width: json['width'] is int ? json['width'] as int : null,
        height: json['height'] is int ? json['height'] as int : null,
        sourceType: json['sourceType']?.toString() ?? 'upload',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Thin client for the four `/stickers*` server endpoints. Shared by the
/// picker grid below, comments_sheet.dart's attach menu, and (a later phase)
/// the chat composer.
class StickerRepo {
  StickerRepo._();
  static final instance = StickerRepo._();

  Future<List<StickerItem>> fetchStickers() async {
    final data = await Api.instance.get('/stickers');
    return (data is List ? data : const [])
        .whereType<Map>()
        .map((e) => StickerItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Saves an existing media URL (an image, or the output of
  /// [convertVideoToSticker]) into the user's library. Safe to call more than
  /// once for the same URL — the server upserts on `(ownerId, url)`.
  Future<StickerItem?> saveUrl(String url, {String sourceType = 'upload'}) async {
    final res = await Api.instance.post('/stickers', body: {
      'url': url,
      'sourceType': sourceType,
    });
    return res is Map ? StickerItem.fromJson(res.cast<String, dynamic>()) : null;
  }

  Future<void> deleteSticker(String id) => Api.instance.delete('/stickers/$id');

  /// Uploads a short video (already picked/trimmed to roughly the server's
  /// ~6s cap) and returns the resulting animated WebP/GIF sticker.
  Future<StickerItem?> convertVideoToSticker(XFile video) async {
    final bytes = await video.readAsBytes();
    final name = video.name.isNotEmpty ? video.name : 'clip.mp4';
    final res = await Api.instance
        .upload('/stickers/convert', MultipartFile.fromBytes(bytes, filename: name));
    return res is Map ? StickerItem.fromJson(res.cast<String, dynamic>()) : null;
  }
}

/// Long-press-to-save helper: saves [url] into the current user's sticker
/// library and shows a brief confirmation. Used by comments_sheet.dart (and
/// reusable from chat in a later phase) wherever a sticker/image attachment
/// is rendered.
Future<void> saveMediaToStickerLibrary(
  BuildContext context,
  String url, {
  String sourceType = 'comment',
}) async {
  try {
    await StickerRepo.instance.saveUrl(url, sourceType: sourceType);
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to your stickers')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save sticker: $e')));
    }
  }
}

/// Opens the sticker library as a modal bottom sheet. Resolves with the
/// picked sticker's URL, or null if dismissed without a pick.
Future<String?> showStickerPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: KliqColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: StickerPickerGrid(
          onStickerSelected: (url) => Navigator.of(ctx).pop(url),
        ),
      ),
    ),
  );
}

/// Grid picker over the current user's saved stickers, plus a "video to
/// sticker" affordance that converts a short clip into a new one. Reusable
/// as-is: embedded in comments_sheet.dart's attach menu now, and intended for
/// a chat composer / emoji-picker grid in a later phase — the only public
/// surface is [onStickerSelected].
class StickerPickerGrid extends StatefulWidget {
  const StickerPickerGrid({super.key, required this.onStickerSelected});

  final ValueChanged<String> onStickerSelected;

  @override
  State<StickerPickerGrid> createState() => _StickerPickerGridState();
}

class _StickerPickerGridState extends State<StickerPickerGrid> {
  List<StickerItem> _stickers = const [];
  bool _loading = true;
  String? _error;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stickers = await StickerRepo.instance.fetchStickers();
      if (!mounted) return;
      setState(() {
        _stickers = stickers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _convertVideo() async {
    try {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 6),
      );
      if (video == null) return;
      setState(() => _converting = true);
      final sticker = await StickerRepo.instance.convertVideoToSticker(video);
      if (!mounted) return;
      if (sticker != null) {
        setState(() => _stickers = [sticker, ..._stickers]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not create sticker: $e')));
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: KliqColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text('Your stickers',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              TextButton.icon(
                onPressed: _converting ? null : _convertVideo,
                icon: _converting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Video to sticker'),
              ),
            ],
          ),
        ),
        SizedBox(height: 220, child: _body()),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: KliqColors.cyan),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Text('Could not load stickers',
            style: const TextStyle(color: KliqColors.textMuted, fontSize: 12)),
      );
    }
    if (_stickers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'No stickers yet — long-press an image in a chat/comment, or make one from a video above',
            textAlign: TextAlign.center,
            style: TextStyle(color: KliqColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: _stickers.length,
      itemBuilder: (context, i) {
        final s = _stickers[i];
        return GestureDetector(
          onTap: () => widget.onStickerSelected(s.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: KliqColors.surfaceElevated,
              child: Image.network(
                Api.instance.mediaUrl(s.url),
                fit: BoxFit.cover,
                errorBuilder: (c, e, st) => const Icon(Icons.broken_image_outlined,
                    size: 18, color: KliqColors.textMuted),
              ),
            ),
          ),
        );
      },
    );
  }
}

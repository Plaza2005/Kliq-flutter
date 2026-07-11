import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// Identity of every uploadable module in the app. The Upload Hub lists
/// these; each entry navigates to its own independent studio page.
class StudioModule {
  const StudioModule({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
    required this.color,
  });

  final String key;
  final String label;
  final String description;
  final IconData icon;
  final String route;
  final Color color;
}

const studioModules = <StudioModule>[
  StudioModule(
    key: 'posts',
    label: 'Posts',
    description: 'Photos, carousels & text threads',
    icon: Icons.grid_on,
    route: '/studio/posts',
    color: KliqColors.cyan,
  ),
  StudioModule(
    key: 'reels',
    label: 'Reels',
    description: 'Short vertical videos',
    icon: Icons.movie_creation_outlined,
    route: '/studio/reels',
    color: KliqColors.pink,
  ),
  StudioModule(
    key: 'kliqtube',
    label: 'KliqTube',
    description: 'Long-form video channel',
    icon: Icons.video_library_outlined,
    route: '/studio/kliqtube',
    color: Color(0xFFF87171),
  ),
  StudioModule(
    key: 'stories',
    label: 'Stories',
    description: '24-hour ephemeral moments',
    icon: Icons.auto_stories_outlined,
    route: '/studio/stories',
    color: KliqColors.purple,
  ),
  StudioModule(
    key: 'live',
    label: 'Live',
    description: 'Stream to your audience in realtime',
    icon: Icons.sensors,
    route: '/studio/live',
    color: Color(0xFFEF4444),
  ),
  StudioModule(
    key: 'marketplace',
    label: 'Marketplace',
    description: 'Sell products to your followers',
    icon: Icons.storefront_outlined,
    route: '/studio/marketplace',
    color: Color(0xFF34D399),
  ),
  StudioModule(
    key: 'kliqstream',
    label: 'KliqStream',
    description: 'Original shows & series',
    icon: Icons.theaters_outlined,
    route: '/studio/kliqstream',
    color: Color(0xFFFBBF24),
  ),
];

/// Picks an image (gallery) and uploads it; returns the server URL.
Future<String?> pickAndUploadImage(BuildContext context) async {
  try {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final res = await Api.instance
        .upload('/upload', MultipartFile.fromBytes(bytes, filename: picked.name));
    return res is Map ? res['url']?.toString() : null;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
    return null;
  }
}

/// Picks a video file and uploads it; returns the server URL.
Future<String?> pickAndUploadVideo(BuildContext context) async {
  try {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.video, withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return null;
    final res = await Api.instance.upload(
        '/upload', MultipartFile.fromBytes(file.bytes!, filename: file.name));
    return res is Map ? res['url']?.toString() : null;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
    return null;
  }
}

/// Upload tile used across the module studios. When an image URL is set it
/// shows the actual picture as a preview; videos show a ready state with
/// the filename-style label.
class MediaSlot extends StatelessWidget {
  const MediaSlot({
    super.key,
    required this.label,
    required this.icon,
    required this.url,
    required this.busy,
    required this.onPick,
    this.isImage = true,
    this.height = 110,
  });

  final String label;
  final IconData icon;
  final String? url;
  final bool busy;
  final VoidCallback onPick;
  final bool isImage;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPick,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: KliqColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: url != null ? KliqColors.cyan : KliqColors.border),
        ),
        child: busy
            ? const Center(
                child: CircularProgressIndicator(color: KliqColors.cyan))
            : url != null && isImage
                // Live preview of the uploaded image
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        Api.instance.mediaUrl(url!),
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: KliqColors.textMuted)),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Tap to replace',
                              style: TextStyle(fontSize: 10.5)),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(url != null ? Icons.check_circle : icon,
                            color: url != null
                                ? KliqColors.success
                                : KliqColors.textMuted,
                            size: 30),
                        const SizedBox(height: 8),
                        Text(
                            url != null
                                ? 'Video ready — tap to replace'
                                : label,
                            style: const TextStyle(
                                color: KliqColors.textSecondary,
                                fontSize: 12.5)),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Removable thumbnail used by multi-image pickers (post carousels,
/// product galleries).
class MediaThumb extends StatelessWidget {
  const MediaThumb({super.key, required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            Api.instance.mediaUrl(url),
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
                width: 84,
                height: 84,
                color: KliqColors.surfaceElevated,
                child: const Icon(Icons.broken_image_outlined,
                    size: 18, color: KliqColors.textMuted)),
          ),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 13),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Add photo" tile that sits beside [MediaThumb]s in a gallery row.
class AddMediaTile extends StatelessWidget {
  const AddMediaTile({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: KliqColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KliqColors.border),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: KliqColors.cyan)))
            : const Icon(Icons.add_photo_alternate_outlined,
                color: KliqColors.textMuted),
      ),
    );
  }
}

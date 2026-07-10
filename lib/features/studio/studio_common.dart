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

/// Upload progress/preview tile used across the module studios.
class MediaSlot extends StatelessWidget {
  const MediaSlot({
    super.key,
    required this.label,
    required this.icon,
    required this.url,
    required this.busy,
    required this.onPick,
  });

  final String label;
  final IconData icon;
  final String? url;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onPick,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: KliqColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: url != null ? KliqColors.cyan : KliqColors.border),
        ),
        child: Center(
          child: busy
              ? const CircularProgressIndicator(color: KliqColors.cyan)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(url != null ? Icons.check_circle : icon,
                        color: url != null
                            ? KliqColors.success
                            : KliqColors.textMuted,
                        size: 30),
                    const SizedBox(height: 8),
                    Text(url != null ? 'Ready — tap to replace' : label,
                        style: const TextStyle(
                            color: KliqColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
        ),
      ),
    );
  }
}

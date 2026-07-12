import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import 'studio_common.dart';

/// Independent studio pages for Posts, Reels, Stories and Live.
/// Each page owns its complete upload flow — the Upload Hub only links here.

/// Shared layout: header + composer card + "your content" list.
class StudioModuleScaffold extends StatelessWidget {
  const StudioModuleScaffold({
    super.key,
    required this.module,
    required this.composer,
    this.contentList,
  });

  final StudioModule module;
  final Widget composer;
  final Widget? contentList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${module.label} Studio',
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module.icon, color: module.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(module.description,
                    style: const TextStyle(
                        color: KliqColors.textSecondary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KliqColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KliqColors.border),
            ),
            child: composer,
          ),
          if (contentList != null) ...[
            const SizedBox(height: 22),
            contentList!,
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class PublishButton extends StatelessWidget {
  const PublishButton(
      {super.key, required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: KliqColors.gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: busy ? null : onTap,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ── Posts Studio ───────────────────────────────────────────────────────────

class PostsStudioPage extends StatefulWidget {
  const PostsStudioPage({super.key});

  @override
  State<PostsStudioPage> createState() => _PostsStudioPageState();
}

class _PostsStudioPageState extends State<PostsStudioPage> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _imageUrls = <String>[];
  bool _uploading = false;
  bool _publishing = false;

  static const _maxPhotos = 10;

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_imageUrls.length >= _maxPhotos) return;
    setState(() => _uploading = true);
    final url = await pickAndUploadImage(context);
    if (mounted) {
      setState(() {
        if (url != null) _imageUrls.add(url);
        _uploading = false;
      });
    }
  }

  Future<void> _publish() async {
    if (_caption.text.trim().isEmpty && _imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a photo or write something first')));
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/posts', body: {
        'body': _caption.text.trim(),
        'mediaUrls': _imageUrls,
        'mediaType': _imageUrls.isEmpty
            ? 'text'
            : (_imageUrls.length > 1 ? 'carousel' : 'image'),
        if (_location.text.trim().isNotEmpty)
          'location': _location.text.trim(),
      });
      messenger.showSnackBar(
          const SnackBar(content: Text('Post published 🎉')));
      _caption.clear();
      _location.clear();
      setState(() {
        _imageUrls.clear();
        _publishing = false;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
      setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioModuleScaffold(
      module: moduleByKey('posts'),
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _caption,
            maxLines: 4,
            maxLength: 2200,
            decoration: const InputDecoration(
                hintText:
                    'Write a caption or a text thread… #hashtags and '
                    '@mentions are tappable'),
          ),
          const SizedBox(height: 4),
          // ── Photo gallery: up to 10 images become a carousel ─────────
          Text(
            'Photos (${_imageUrls.length}/$_maxPhotos) — more than one '
            'becomes a swipeable carousel',
            style: const TextStyle(
                color: KliqColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _imageUrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MediaThumb(
                      url: _imageUrls[i],
                      onRemove: () =>
                          setState(() => _imageUrls.removeAt(i)),
                    ),
                  ),
                if (_imageUrls.length < _maxPhotos)
                  AddMediaTile(busy: _uploading, onTap: _addPhoto),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _location,
            decoration: const InputDecoration(
              hintText: 'Add location (optional)',
              prefixIcon: Icon(Icons.location_on_outlined,
                  size: 18, color: KliqColors.textMuted),
            ),
          ),
          const SizedBox(height: 14),
          PublishButton(
              label: _imageUrls.length > 1
                  ? 'Publish Carousel (${_imageUrls.length} photos)'
                  : 'Publish Post',
              busy: _publishing,
              onTap: _publish),
        ],
      ),
    );
  }
}

// ── Reels Studio ───────────────────────────────────────────────────────────

class ReelsStudioPage extends StatefulWidget {
  const ReelsStudioPage({super.key});

  @override
  State<ReelsStudioPage> createState() => _ReelsStudioPageState();
}

class _ReelsStudioPageState extends State<ReelsStudioPage> {
  final _caption = TextEditingController();
  final _soundName = TextEditingController();
  String? _videoUrl;
  String? _coverUrl;
  bool _videoBusy = false;
  bool _coverBusy = false;
  bool _publishing = false;
  bool _allowComments = true;
  bool _allowRemix = true;

  @override
  void dispose() {
    _caption.dispose();
    _soundName.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    setState(() => _videoBusy = true);
    final url = await pickAndUploadVideo(context);
    if (mounted) {
      setState(() {
        if (url != null) _videoUrl = url;
        _videoBusy = false;
      });
    }
  }

  Future<void> _pickCover() async {
    setState(() => _coverBusy = true);
    final url = await pickAndUploadImage(context);
    if (mounted) {
      setState(() {
        if (url != null) _coverUrl = url;
        _coverBusy = false;
      });
    }
  }

  Future<void> _publish() async {
    if (_videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a video for your reel')));
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/reels', body: {
        'caption': _caption.text.trim(),
        'videoUrl': _videoUrl,
        if (_coverUrl != null) 'thumbnailUrl': _coverUrl,
        if (_soundName.text.trim().isNotEmpty)
          'soundName': _soundName.text.trim(),
        'allowComments': _allowComments,
        'allowRemix': _allowRemix,
      });
      messenger
          .showSnackBar(const SnackBar(content: Text('Reel published 🎬')));
      _caption.clear();
      _soundName.clear();
      setState(() {
        _videoUrl = null;
        _coverUrl = null;
        _publishing = false;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
      setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioModuleScaffold(
      module: moduleByKey('reels'),
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaSlot(
            label: 'Pick a vertical video (15s – 3min)',
            icon: Icons.video_call_outlined,
            url: _videoUrl,
            busy: _videoBusy,
            isImage: false,
            onPick: _pickVideo,
          ),
          const SizedBox(height: 10),
          MediaSlot(
            label: 'Cover image (optional — shown in grids)',
            icon: Icons.image_outlined,
            url: _coverUrl,
            busy: _coverBusy,
            height: 90,
            onPick: _pickCover,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            maxLines: 2,
            maxLength: 500,
            decoration:
                const InputDecoration(hintText: 'Caption with #hashtags…'),
          ),
          TextField(
            controller: _soundName,
            decoration: const InputDecoration(
              hintText: 'Sound name (optional, defaults to Original audio)',
              prefixIcon: Icon(Icons.music_note,
                  size: 18, color: KliqColors.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow comments',
                style: TextStyle(fontSize: 13.5)),
            value: _allowComments,
            activeThumbColor: KliqColors.cyan,
            onChanged: (v) => setState(() => _allowComments = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow remix & duet',
                style: TextStyle(fontSize: 13.5)),
            value: _allowRemix,
            activeThumbColor: KliqColors.cyan,
            onChanged: (v) => setState(() => _allowRemix = v),
          ),
          const SizedBox(height: 8),
          PublishButton(
              label: 'Publish Reel', busy: _publishing, onTap: _publish),
        ],
      ),
    );
  }
}

// ── Stories Studio ─────────────────────────────────────────────────────────

class StoriesStudioPage extends StatefulWidget {
  const StoriesStudioPage({super.key});

  @override
  State<StoriesStudioPage> createState() => _StoriesStudioPageState();
}

class _StoriesStudioPageState extends State<StoriesStudioPage> {
  final _overlay = TextEditingController();
  String? _imageUrl;
  bool _uploading = false;
  bool _publishing = false;

  @override
  void dispose() {
    _overlay.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _uploading = true);
    final url = await pickAndUploadImage(context);
    if (mounted) {
      setState(() {
        if (url != null) _imageUrl = url;
        _uploading = false;
      });
    }
  }

  Future<void> _publish() async {
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a photo for your story')));
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/stories', body: {
        'mediaUrl': _imageUrl,
        'mediaType': 'image',
        if (_overlay.text.trim().isNotEmpty) 'body': _overlay.text.trim(),
      });
      messenger.showSnackBar(const SnackBar(
          content: Text('Story posted — live for 24 hours ✨')));
      _overlay.clear();
      setState(() {
        _imageUrl = null;
        _publishing = false;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Post failed: $e')));
      setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioModuleScaffold(
      module: moduleByKey('stories'),
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tall 9:16-ish preview so the story looks like it will on screen
          MediaSlot(
            label: 'Pick a photo for your story',
            icon: Icons.add_photo_alternate_outlined,
            url: _imageUrl,
            busy: _uploading,
            height: 220,
            onPick: _pick,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _overlay,
            maxLength: 120,
            decoration: const InputDecoration(
              hintText: 'Text overlay (optional)',
              prefixIcon: Icon(Icons.text_fields,
                  size: 18, color: KliqColors.textMuted),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Stories disappear after 24 hours and show with a gradient ring '
            'in the story bar.',
            style: TextStyle(color: KliqColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          PublishButton(
              label: 'Post Story', busy: _publishing, onTap: _publish),
        ],
      ),
    );
  }
}

// ── Live Studio ────────────────────────────────────────────────────────────

class LiveStudioPage extends StatelessWidget {
  const LiveStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<Session>();
    return StudioModuleScaffold(
      module: moduleByKey('live'),
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ready to stream?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Go live to your followers with realtime chat, gifts and viewer '
            'counts. Streams appear in the Live Now tab across KLIQ.',
            style: TextStyle(color: KliqColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          PublishButton(
            label: 'Go Live Now',
            busy: false,
            onTap: () => context.push('/go-live'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: KliqColors.textPrimary,
              side: const BorderSide(color: KliqColors.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: () => context.push('/live'),
            child: const Text('See who is live right now'),
          ),
        ],
      ),
      contentList: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KliqColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KliqColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tips for a great stream',
                style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              '• Announce your stream with a post beforehand\n'
              '• Interact with the chat — reply to viewers by name\n'
              '• Thank gift senders on air; gifts convert to diamonds\n'
              '• Stream at least 20 minutes so discovery can pick you up',
              style: TextStyle(
                  color: KliqColors.textSecondary, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

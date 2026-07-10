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
  String? _imageUrl;
  bool _uploading = false;
  bool _publishing = false;

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
    if (_caption.text.trim().isEmpty && _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add a photo or write something first')));
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/posts', body: {
        'body': _caption.text.trim(),
        'mediaUrls': _imageUrl == null ? <String>[] : [_imageUrl],
        'mediaType': _imageUrl == null ? 'text' : 'image',
      });
      messenger.showSnackBar(
          const SnackBar(content: Text('Post published 🎉')));
      _caption.clear();
      setState(() {
        _imageUrl = null;
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
      module: studioModules[0],
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _caption,
            maxLines: 4,
            decoration: const InputDecoration(
                hintText: 'Write a caption or a text thread…'),
          ),
          const SizedBox(height: 12),
          MediaSlot(
            label: 'Add a photo',
            icon: Icons.add_photo_alternate_outlined,
            url: _imageUrl,
            busy: _uploading,
            onPick: _pick,
          ),
          const SizedBox(height: 14),
          PublishButton(
              label: 'Publish Post', busy: _publishing, onTap: _publish),
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
  String? _videoUrl;
  bool _uploading = false;
  bool _publishing = false;

  Future<void> _pick() async {
    setState(() => _uploading = true);
    final url = await pickAndUploadVideo(context);
    if (mounted) {
      setState(() {
        if (url != null) _videoUrl = url;
        _uploading = false;
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
      });
      messenger
          .showSnackBar(const SnackBar(content: Text('Reel published 🎬')));
      _caption.clear();
      setState(() {
        _videoUrl = null;
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
      module: studioModules[1],
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaSlot(
            label: 'Pick a vertical video (15s – 3min)',
            icon: Icons.video_call_outlined,
            url: _videoUrl,
            busy: _uploading,
            onPick: _pick,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            maxLines: 2,
            decoration: const InputDecoration(
                hintText: 'Caption with #hashtags…'),
          ),
          const SizedBox(height: 14),
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
  String? _imageUrl;
  bool _uploading = false;
  bool _publishing = false;

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
      await Api.instance.post('/stories',
          body: {'mediaUrl': _imageUrl, 'mediaType': 'image'});
      messenger.showSnackBar(const SnackBar(
          content: Text('Story posted — live for 24 hours ✨')));
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
      module: studioModules[3],
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaSlot(
            label: 'Pick a photo for your story',
            icon: Icons.add_photo_alternate_outlined,
            url: _imageUrl,
            busy: _uploading,
            onPick: _pick,
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
      module: studioModules[4],
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

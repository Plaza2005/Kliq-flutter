import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../common/kliq_video.dart';
import '../discover/discover_common.dart';

/// KliqTube — YouTube-style long-form video: browse, watch, channel,
/// playlists.

class KliqTubePage extends StatefulWidget {
  const KliqTubePage({super.key});

  @override
  State<KliqTubePage> createState() => _KliqTubePageState();
}

class _KliqTubePageState extends State<KliqTubePage> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/kliqtube');
      if (!mounted) return;
      setState(() {
        _videos = asMapList(data, key: 'videos');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KliqTube',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.playlist_play),
              onPressed: () => context.push('/kliqtube/playlists')),
          IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/search')),
          IconButton(
              icon: const Icon(Icons.video_call_outlined),
              onPressed: () => context.push('/studio/kliqtube')),
        ],
      ),
      body: _loading
          ? const CenterSpinner()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _videos.isEmpty
                  ? const EmptyState(
                      icon: Icons.video_library_outlined,
                      title: 'No videos yet')
                  : RefreshIndicator(
                      color: KliqColors.cyan,
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _videos.length,
                        itemBuilder: (context, i) =>
                            TubeVideoCard(video: _videos[i]),
                      ),
                    ),
    );
  }
}

class TubeVideoCard extends StatelessWidget {
  const TubeVideoCard({super.key, required this.video});

  final Map<String, dynamic> video;

  @override
  Widget build(BuildContext context) {
    final author = authorOf(video);
    return InkWell(
      onTap: () => context.push('/kliqtube/watch/${video['id']}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                  aspectRatio: 16 / 9,
                  child: NetImg(pickStr(video, ['thumbnailUrl']))),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(fmtDuration(pickInt(video, ['duration'])),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    final a = asMap(video['author'] ?? video['user']);
                    context.push('/kliqtube/channel/${a['id'] ?? ''}');
                  },
                  child: KliqAvatar(author['avatarUrl'], radius: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pickStr(video, ['title']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14.5)),
                      const SizedBox(height: 4),
                      Text(
                        '${author['displayName']} · '
                        '${fmtCount(pickInt(video, ['viewCount']))} views · '
                        '${timeAgo(video['createdAt']?.toString())}',
                        style: const TextStyle(
                            color: KliqColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class KliqTubeWatchPage extends StatefulWidget {
  const KliqTubeWatchPage({super.key, required this.videoId});

  final String videoId;

  @override
  State<KliqTubeWatchPage> createState() => _KliqTubeWatchPageState();
}

class _KliqTubeWatchPageState extends State<KliqTubeWatchPage> {
  Map<String, dynamic>? _video;
  List<Map<String, dynamic>> _related = [];
  bool _loading = true;
  bool _liked = false;
  bool _subscribed = false;
  bool _descExpanded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/kliqtube/${widget.videoId}');
      final all = await Api.instance.get('/kliqtube').catchError((_) => []);
      if (!mounted) return;
      setState(() {
        _video = asMap(data);
        _related = asMapList(all, key: 'videos')
            .where((v) => v['id'] != widget.videoId)
            .take(8)
            .toList();
        _liked = pickBool(_video!, ['isLiked', 'liked']);
        _loading = false;
      });
      Api.instance
          .post('/kliqtube/${widget.videoId}/view')
          .catchError((_) => null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    if (_error != null || _video == null) {
      return Scaffold(
          appBar: AppBar(),
          body: ErrorState(message: _error ?? 'Video not found', onRetry: _load));
    }
    final v = _video!;
    final author = authorOf(v);
    final videoUrl = pickStr(v, ['videoUrl', 'mediaUrl']);

    return Scaffold(
      appBar: AppBar(title: const Text('KliqTube')),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: videoUrl.isNotEmpty
                ? KliqVideo(url: videoUrl)
                : NetImg(pickStr(v, ['thumbnailUrl'])),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickStr(v, ['title']),
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '${fmtCount(pickInt(v, ['viewCount']))} views · '
                  '${timeAgo(v['createdAt']?.toString())}',
                  style: const TextStyle(
                      color: KliqColors.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _pill(
                      icon: _liked
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      label: fmtCount(
                          pickInt(v, ['likeCount']) + (_liked ? 1 : 0)),
                      active: _liked,
                      onTap: () {
                        setState(() => _liked = !_liked);
                        Api.instance
                            .post('/posts/${v['id']}/like')
                            .catchError((_) => null);
                      },
                    ),
                    const SizedBox(width: 8),
                    _pill(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Link copied')));
                        }),
                    const SizedBox(width: 8),
                    _pill(
                        icon: Icons.bookmark_border,
                        label: 'Save',
                        onTap: () {
                          Api.instance
                              .post('/posts/${v['id']}/save')
                              .catchError((_) => null);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Saved')));
                        }),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    KliqAvatar(author['avatarUrl'], radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(author['displayName']!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text('@${author['username']}',
                              style: const TextStyle(
                                  color: KliqColors.textMuted,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient:
                            _subscribed ? null : KliqColors.gradient,
                        color: _subscribed
                            ? KliqColors.surfaceElevated
                            : null,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextButton(
                        onPressed: () {
                          setState(() => _subscribed = !_subscribed);
                          final a = asMap(v['author'] ?? v['user']);
                          Api.instance
                              .post('/users/${a['id']}/follow')
                              .catchError((_) => null);
                        },
                        child: Text(
                            _subscribed ? 'Subscribed' : 'Subscribe',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () =>
                      setState(() => _descExpanded = !_descExpanded),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: KliqColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      pickStr(v, ['description', 'body'],
                          fallback: 'No description'),
                      maxLines: _descExpanded ? null : 3,
                      overflow: _descExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: KliqColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Text('Up next',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final r in _related) TubeVideoCard(video: r),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? KliqColors.cyan.withValues(alpha: 0.18)
              : KliqColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active ? KliqColors.cyan : KliqColors.textPrimary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class KliqTubeChannelPage extends StatefulWidget {
  const KliqTubeChannelPage({super.key, required this.channelId});

  final String channelId;

  @override
  State<KliqTubeChannelPage> createState() => _KliqTubeChannelPageState();
}

class _KliqTubeChannelPageState extends State<KliqTubeChannelPage> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await Api.instance.get('/users/${widget.channelId}');
      final all = await Api.instance.get('/kliqtube').catchError((_) => []);
      if (!mounted) return;
      setState(() {
        _user = asMap(user);
        _videos = asMapList(all, key: 'videos').where((v) {
          final a = asMap(v['author'] ?? v['user']);
          return a['id']?.toString() == widget.channelId;
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    final u = _user ?? {};
    return Scaffold(
      appBar: AppBar(title: Text(pickStr(u, ['displayName'], fallback: 'Channel'))),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                KliqAvatar(u['avatarUrl']?.toString(), radius: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pickStr(u, ['displayName', 'username']),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(
                        '@${pickStr(u, ['username'])} · '
                        '${fmtCount(pickInt(u, ['followerCount']))} subscribers · '
                        '${_videos.length} videos',
                        style: const TextStyle(
                            color: KliqColors.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_videos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'No videos on this channel'),
            )
          else
            for (final v in _videos) TubeVideoCard(video: v),
        ],
      ),
    );
  }
}

class KliqTubePlaylistsPage extends StatelessWidget {
  const KliqTubePlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlists')),
      body: FutureBuilder(
        future: Api.instance.get('/kliqtube/playlists').catchError((_) => []),
        builder: (context, snap) {
          if (!snap.hasData) return const CenterSpinner();
          final lists = asMapList(snap.data, key: 'playlists');
          if (lists.isEmpty) {
            return const EmptyState(
                icon: Icons.playlist_play,
                title: 'No playlists yet',
                subtitle: 'Save videos into playlists to watch later');
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, i) {
              final p = lists[i];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                      width: 72,
                      height: 44,
                      child: NetImg(pickStr(p, ['thumbnailUrl']))),
                ),
                title: Text(pickStr(p, ['title', 'name'])),
                subtitle: Text('${pickInt(p, ['videoCount'])} videos',
                    style: const TextStyle(color: KliqColors.textMuted)),
              );
            },
          );
        },
      ),
    );
  }
}

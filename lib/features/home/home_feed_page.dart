import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../shell/action_panel.dart';
import 'feed_models.dart';
import 'widgets/post_card.dart';
import 'widgets/story_bar.dart';

/// The '/home' tab: stories strip + infinite-scroll feed of post cards.
class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  final _scroll = ScrollController();
  final _posts = <Post>[];
  var _stories = <StoryGroup>[];

  String _tab = 'for_you';
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    dataEpoch.addListener(_onDataEpoch);
    _load(reset: true);
    _loadStories();
  }

  @override
  void dispose() {
    dataEpoch.removeListener(_onDataEpoch);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onDataEpoch() {
    if (!mounted) return;
    _load(reset: true);
    _loadStories();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 600) {
      _load();
    }
  }

  Future<void> _loadStories() async {
    try {
      final data = await Api.instance.get('/stories/feed');
      if (data is List && mounted) {
        setState(() {
          _stories = data
              .whereType<Map>()
              .map((e) => StoryGroup.fromJson(e.cast<String, dynamic>()))
              .toList();
        });
      }
    } catch (_) {
      // Story strip is optional — hide on error.
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final nextPage = reset ? 1 : _page + 1;
      final data = await Api.instance
          .get('/posts/feed', query: {'page': '$nextPage', 'tab': _tab});
      final parsed = parseFeed(data);
      if (!mounted) return;
      setState(() {
        if (reset) _posts.clear();
        final known = _posts.map((p) => p.id).toSet();
        _posts.addAll(parsed.posts.where((p) => !known.contains(p.id)));
        _page = nextPage;
        _hasMore = parsed.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (_posts.isEmpty) _error = e.toString();
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_load(reset: true), _loadStories()]);
  }

  Future<void> _createStory() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final res = await Api.instance.upload(
          '/upload', MultipartFile.fromBytes(bytes, filename: picked.name));
      final url = (res is Map) ? res['url']?.toString() : null;
      if (url == null) throw ApiException('Upload failed');
      await Api.instance
          .post('/stories', body: {'mediaUrl': url, 'mediaType': 'image'});
      messenger.showSnackBar(
          const SnackBar(content: Text('Your story has been posted')));
      await _loadStories();
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not post story: $e')));
    }
  }

  void _switchTab(String tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(
        title: const KliqWordmark(size: 20, withLogo: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            onPressed: () => context.push('/inbox'),
          ),
          const ActionPanelButton(),
        ],
      ),
      body: _buildBody(session),
    );
  }

  Widget _buildBody(Session session) {
    if (_loading && _posts.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: KliqColors.cyan));
    }
    if (_error != null && _posts.isEmpty) {
      return _ErrorState(message: _error!, onRetry: () => _load(reset: true));
    }

    return RefreshIndicator(
      color: KliqColors.cyan,
      backgroundColor: KliqColors.surfaceElevated,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _tabBar(),
                StoryBar(
                  groups: _stories,
                  myAvatarUrl: session.user?['avatarUrl'] as String?,
                  onCreateStory: _createStory,
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          if (_posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        size: 48, color: KliqColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      _tab == 'following'
                          ? 'Follow people to see their posts here'
                          : 'No posts yet',
                      style:
                          const TextStyle(color: KliqColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/create'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create a post'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: _posts.length + 1,
              itemBuilder: (context, i) {
                if (i == _posts.length) {
                  return _hasMore || _loadingMore
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: KliqColors.cyan),
                            ),
                          ),
                        )
                      : const SizedBox(height: 40);
                }
                return PostCard(post: _posts[i], gradientSeed: i);
              },
            ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _tabButton('For You', 'for_you'),
          const SizedBox(width: 28),
          _tabButton('Following', 'following'),
        ],
      ),
    );
  }

  Widget _tabButton(String label, String value) {
    final active = _tab == value;
    return GestureDetector(
      onTap: () => _switchTab(value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color:
                  active ? KliqColors.textPrimary : KliqColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 36,
            decoration: BoxDecoration(
              gradient: active ? KliqColors.storyRing : null,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 44, color: KliqColors.textMuted),
            const SizedBox(height: 12),
            const Text('Could not load your feed',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_humanize(message),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: KliqColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  /// Keep raw server strings like "Internal Server Error" off the screen.
  static String _humanize(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('internal server error') || lower.contains('500')) {
      return 'The server had a hiccup. Pull to refresh or tap Retry.';
    }
    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('network')) {
      return "Can't reach the server. Check your connection and try again.";
    }
    return message;
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import 'discover_common.dart';

/// Explore tab — trending hashtags, section chips and a masonry grid of
/// trending content with tap-through to detail pages. Mirrors prot_3's
/// Explore.tsx / Search.tsx empty-state layout.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

enum _Section { posts, reels, live }

class _ExplorePageState extends State<ExplorePage> {
  _Section _section = _Section.posts;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _trendingTags = [];
  final Map<_Section, List<Map<String, dynamic>>> _data = {};

  @override
  void initState() {
    super.initState();
    dataEpoch.addListener(_onDataEpoch);
    _load();
  }

  @override
  void dispose() {
    dataEpoch.removeListener(_onDataEpoch);
    super.dispose();
  }

  void _onDataEpoch() {
    if (!mounted) return;
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) _data.clear();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_trendingTags.isEmpty || refresh) {
        try {
          _trendingTags = asMapList(await Api.instance.get('/search/trending'));
        } catch (_) {
          _trendingTags = [];
        }
      }
      if (!_data.containsKey(_section)) {
        _data[_section] = await _fetchSection(_section);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSection(_Section s) async {
    switch (s) {
      case _Section.posts:
        return asMapList(await Api.instance.get('/search/explore'));
      case _Section.reels:
        return asMapList(await Api.instance.get('/posts/reels'));
      case _Section.live:
        return asMapList(await Api.instance.get('/live/streams'));
    }
  }

  void _selectSection(_Section s) {
    if (_section == s) return;
    setState(() => _section = s);
    if (!_data.containsKey(s)) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: KliqColors.cyan,
          onRefresh: () => _load(refresh: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _searchBar(context)),
              SliverToBoxAdapter(child: _sectionChips()),
              if (_trendingTags.isNotEmpty)
                SliverToBoxAdapter(child: _trendingRow(context)),
              ..._body(),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header pieces ──────────────────────────────────────────────────────

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: KliqColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: KliqColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search,
                        size: 18, color: KliqColors.textMuted),
                    SizedBox(width: 8),
                    Text('Search KLIQ...',
                        style: TextStyle(
                            color: KliqColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionChips() {
    const labels = {
      _Section.posts: ('Posts', Icons.grid_on),
      _Section.reels: ('Reels', Icons.movie_outlined),
      _Section.live: ('Live', Icons.sensors),
    };
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final s in _Section.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _section == s,
                onSelected: (_) => _selectSection(s),
                showCheckmark: false,
                avatar: Icon(labels[s]!.$2,
                    size: 15,
                    color: _section == s ? Colors.black : KliqColors.textSecondary),
                label: Text(labels[s]!.$1),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _section == s ? Colors.black : KliqColors.textPrimary,
                ),
                selectedColor: KliqColors.cyan,
                backgroundColor: KliqColors.surfaceElevated,
                side: const BorderSide(color: KliqColors.border),
              ),
            ),
        ],
      ),
    );
  }

  Widget _trendingRow(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          for (final t in _trendingTags.take(10))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                onPressed: () {
                  final tag = pickStr(t, ['tag', 'name']).replaceAll('#', '');
                  if (tag.isNotEmpty) context.push('/hashtag/$tag');
                },
                avatar: const Icon(Icons.trending_up,
                    size: 14, color: KliqColors.pink),
                label: Text(pickStr(t, ['tag', 'name'])),
                labelStyle: const TextStyle(
                    fontSize: 12, color: KliqColors.textSecondary),
                backgroundColor: KliqColors.surface,
                side: const BorderSide(color: KliqColors.border),
              ),
            ),
        ],
      ),
    );
  }

  // ── Body per section ───────────────────────────────────────────────────

  List<Widget> _body() {
    if (_loading) {
      return const [SliverToBoxAdapter(child: CenterSpinner())];
    }
    if (_error != null) {
      return [
        SliverToBoxAdapter(
            child: ErrorState(message: _error!, onRetry: () => _load())),
      ];
    }
    final items = _data[_section] ?? [];
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.explore_outlined,
            title: 'Nothing here yet',
            subtitle: 'Check back soon for trending ${_section.name}.',
          ),
        ),
      ];
    }
    switch (_section) {
      case _Section.posts:
        return [_masonry(items)];
      case _Section.reels:
        return [_reelsGrid(items)];
      case _Section.live:
        return [_liveList(items)];
    }
  }

  /// 3-column masonry grid built from round-robin columns.
  Widget _masonry(List<Map<String, dynamic>> items) {
    const cols = 3;
    final columns = List.generate(cols, (_) => <Map<String, dynamic>>[]);
    for (var i = 0; i < items.length; i++) {
      columns[i % cols].add(items[i]);
    }
    const heights = [150.0, 210.0, 180.0, 240.0, 165.0];
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      sliver: SliverToBoxAdapter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < cols; c++)
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < columns[c].length; i++)
                      _postTile(columns[c][i],
                          heights[(c + i * cols) % heights.length]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _postTile(Map<String, dynamic> p, double height) {
    final media = pickStr(p, ['thumbUrl', 'thumbnailUrl', 'mediaUrl']).isEmpty
        ? (asMapList(p['mediaUrls']).isEmpty
            ? (p['mediaUrls'] is List && (p['mediaUrls'] as List).isNotEmpty
                ? (p['mediaUrls'] as List).first.toString()
                : '')
            : '')
        : pickStr(p, ['thumbUrl', 'thumbnailUrl', 'mediaUrl']);
    final body = pickStr(p, ['body', 'caption']);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () => context.push('/post/${p['id']}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (media.isNotEmpty)
                  NetImg(media)
                else
                  Container(
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                      colors: [Color(0xFF3B0764), Colors.black],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )),
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    child: Text(body,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: _overlayStat(Icons.favorite,
                      fmtCount(pickInt(p, ['likeCount']))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reelsGrid(List<Map<String, dynamic>> items) {
    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 9 / 15,
        ),
        delegate: SliverChildBuilderDelegate(
          childCount: items.length,
          (context, i) {
            final r = items[i];
            return GestureDetector(
              onTap: () => context.push('/reels'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImg(pickStr(r, ['thumbnailUrl', 'thumbUrl', 'mediaUrl'])),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: _overlayStat(Icons.play_arrow,
                          fmtCount(pickInt(r, ['viewCount', 'likeCount']))),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _liveList(List<Map<String, dynamic>> items) {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final l = items[i];
          final user = authorOf(l);
          return GestureDetector(
            onTap: () => context.push('/live/${l['id']}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImg(pickStr(l, ['thumbnailUrl', 'thumbUrl'])),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: KliqColors.live,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LIVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _overlayStat(Icons.visibility,
                          fmtCount(pickInt(l, ['viewerCount']))),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Row(
                        children: [
                          KliqAvatar(user['avatarUrl'], radius: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pickStr(l, ['title']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Text('@${user['username']}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _overlayStat(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

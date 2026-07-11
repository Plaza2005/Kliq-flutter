import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../common/kliq_video.dart';
import '../discover/discover_common.dart';

/// KliqStream — Netflix-style originals catalogue: featured banner,
/// category rows, search, show page with episodes, full-screen player,
/// My List.

class KliqStreamPage extends StatefulWidget {
  const KliqStreamPage({super.key});

  @override
  State<KliqStreamPage> createState() => _KliqStreamPageState();
}

class _KliqStreamPageState extends State<KliqStreamPage> {
  Map<String, dynamic> _catalogue = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/kliqstream');
      if (!mounted) return;
      setState(() {
        _catalogue = asMap(data);
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
    final featured = asMapList(_catalogue['featured'], key: 'featured');
    final categories = asMap(_catalogue['categories']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KliqStream',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search shows',
              onPressed: () => context.push('/kliqstream/search')),
          IconButton(
              icon: const Icon(Icons.bookmark_outline),
              onPressed: () => context.push('/kliqstream/mylist')),
        ],
      ),
      body: _loading
          ? const CenterSpinner()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : ListView(
                  children: [
                    if (featured.isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: PageView(
                          children: [
                            for (final show in featured)
                              _FeaturedBanner(show: show),
                          ],
                        ),
                      ),
                    for (final entry in categories.entries)
                      _CategoryRow(
                          title: entry.key,
                          shows: asMapList(entry.value)),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.show});

  final Map<String, dynamic> show;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/kliqstream/show/${show['id']}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          NetImg(pickStr(show, ['bannerUrl', 'posterUrl'])),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickStr(show, ['title']),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${pickStr(show, ['category'])} · ${pickInt(show, ['year'], fallback: 2026)}',
                  style: const TextStyle(
                      color: KliqColors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.title, required this.shows});

  final String title;
  final List<Map<String, dynamic>> shows;

  @override
  Widget build(BuildContext context) {
    if (shows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 168,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: shows.length,
            itemBuilder: (context, i) => ShowPoster(show: shows[i]),
          ),
        ),
      ],
    );
  }
}

class ShowPoster extends StatelessWidget {
  const ShowPoster({super.key, required this.show});

  final Map<String, dynamic> show;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/kliqstream/show/${show['id']}'),
      child: Container(
        width: 112,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: NetImg(pickStr(show, ['posterUrl', 'thumbnailUrl'])),
        ),
      ),
    );
  }
}

class KliqStreamShowPage extends StatefulWidget {
  const KliqStreamShowPage({super.key, required this.showId});

  final String showId;

  @override
  State<KliqStreamShowPage> createState() => _KliqStreamShowPageState();
}

class _KliqStreamShowPageState extends State<KliqStreamShowPage> {
  Map<String, dynamic>? _show;
  bool _loading = true;
  bool _inList = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/kliqstream/${widget.showId}');
      if (!mounted) return;
      setState(() {
        _show = asMap(data);
        _inList = pickBool(_show!, ['inMyList']);
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

  Future<void> _toggleList() async {
    setState(() => _inList = !_inList);
    Api.instance
        .post('/kliqstream/${widget.showId}/mylist')
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    if (_error != null || _show == null) {
      return Scaffold(
          appBar: AppBar(),
          body: ErrorState(message: _error ?? 'Show not found', onRetry: _load));
    }
    final s = _show!;
    final episodes = asMapList(s['episodes'], key: 'episodes');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NetImg(pickStr(s, ['bannerUrl', 'posterUrl'])),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.9)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pickStr(s, ['title']),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 15, color: KliqColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '${(s['rating'] as num? ?? 4.0).toStringAsFixed(1)} · '
                        '${pickStr(s, ['category'])} · ${pickInt(s, ['year'], fallback: 2026)}',
                        style: const TextStyle(
                            color: KliqColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(pickStr(s, ['description']),
                      style: const TextStyle(
                          color: KliqColors.textSecondary, fontSize: 13.5)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: KliqColors.gradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextButton.icon(
                            onPressed: episodes.isEmpty
                                ? null
                                : () => context.push(
                                    '/kliqstream/watch/${episodes.first['id']}?show=${widget.showId}'),
                            icon: const Icon(Icons.play_arrow,
                                color: Colors.white),
                            label: const Text('Play',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KliqColors.textPrimary,
                          side:
                              const BorderSide(color: KliqColors.border),
                        ),
                        onPressed: _toggleList,
                        icon: Icon(
                            _inList ? Icons.check : Icons.add,
                            size: 18),
                        label:
                            Text(_inList ? 'In My List' : 'My List'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Episodes',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: episodes.length,
            itemBuilder: (context, i) {
              final e = episodes[i];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                      width: 88,
                      height: 50,
                      child: NetImg(pickStr(e, ['thumbnailUrl']))),
                ),
                title: Text(pickStr(e, ['title'], fallback: 'Episode ${i + 1}'),
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(fmtDuration(pickInt(e, ['duration'])),
                    style: const TextStyle(
                        color: KliqColors.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.play_circle_outline,
                    color: KliqColors.cyan),
                onTap: () => context.push(
                    '/kliqstream/watch/${e['id']}?show=${widget.showId}'),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class KliqStreamWatchPage extends StatefulWidget {
  const KliqStreamWatchPage(
      {super.key, required this.episodeId, this.showId});

  final String episodeId;
  final String? showId;

  @override
  State<KliqStreamWatchPage> createState() => _KliqStreamWatchPageState();
}

class _KliqStreamWatchPageState extends State<KliqStreamWatchPage> {
  String? _videoUrl;
  String _title = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Resolve the episode through its show (episodes live inside shows).
      dynamic showData;
      if (widget.showId != null) {
        showData = await Api.instance.get('/kliqstream/${widget.showId}');
      }
      Map<String, dynamic>? episode;
      if (showData != null) {
        episode = asMapList(asMap(showData)['episodes'])
            .where((e) => e['id'] == widget.episodeId)
            .firstOrNull;
      }
      episode ??=
          asMap(await Api.instance.get('/kliqstream/episode/${widget.episodeId}'));
      if (!mounted) return;
      setState(() {
        _videoUrl = pickStr(episode!, ['videoUrl', 'mediaUrl']);
        _title = pickStr(episode, ['title'], fallback: 'Now playing');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(_title)),
      body: _loading
          ? const CenterSpinner()
          : (_videoUrl == null || _videoUrl!.isEmpty)
              ? const EmptyState(
                  icon: Icons.error_outline, title: 'Episode unavailable')
              : Center(child: KliqVideo(url: _videoUrl!)),
    );
  }
}

/// Netflix-style search over the KliqStream catalogue (title, category,
/// description).
class KliqStreamSearchPage extends StatefulWidget {
  const KliqStreamSearchPage({super.key});

  @override
  State<KliqStreamSearchPage> createState() => _KliqStreamSearchPageState();
}

class _KliqStreamSearchPageState extends State<KliqStreamSearchPage> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalogue();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    try {
      final data = await Api.instance.get('/kliqstream');
      final cat = asMap(data);
      final seen = <String>{};
      final all = <Map<String, dynamic>>[];
      void collect(dynamic v) {
        for (final show in asMapList(v)) {
          final id = show['id']?.toString() ?? '';
          if (id.isNotEmpty && seen.add(id)) all.add(show);
        }
      }

      collect(cat['trending']);
      collect(cat['featured']);
      for (final v in asMap(cat['categories']).values) {
        collect(v);
      }
      if (mounted) {
        setState(() {
          _all = all;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? []
          : _all.where((s) {
              return pickStr(s, ['title']).toLowerCase().contains(q) ||
                  pickStr(s, ['category']).toLowerCase().contains(q) ||
                  pickStr(s, ['description']).toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _search,
          decoration: const InputDecoration(
            hintText: 'Search shows, categories…',
            prefixIcon: Icon(Icons.search, color: KliqColors.textMuted),
          ),
        ),
      ),
      body: _loading
          ? const CenterSpinner()
          : !hasQuery
              ? GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 130,
                    childAspectRatio: 2 / 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _all.length,
                  itemBuilder: (context, i) =>
                      ShowPoster(show: _all[i]),
                )
              : _results.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off, title: 'No shows found')
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 130,
                        childAspectRatio: 2 / 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, i) =>
                          ShowPoster(show: _results[i]),
                    ),
    );
  }
}

class KliqStreamMyListPage extends StatefulWidget {
  const KliqStreamMyListPage({super.key});

  @override
  State<KliqStreamMyListPage> createState() => _KliqStreamMyListPageState();
}

class _KliqStreamMyListPageState extends State<KliqStreamMyListPage> {
  List<Map<String, dynamic>> _shows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/kliqstream/mylist');
      if (!mounted) return;
      setState(() {
        _shows = asMapList(data, key: 'shows');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My List')),
      body: _loading
          ? const CenterSpinner()
          : _shows.isEmpty
              ? const EmptyState(
                  icon: Icons.bookmark_outline,
                  title: 'Your list is empty',
                  subtitle: 'Add shows from the catalogue')
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2 / 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _shows.length,
                  itemBuilder: (context, i) =>
                      ShowPoster(show: _shows[i]),
                ),
    );
  }
}

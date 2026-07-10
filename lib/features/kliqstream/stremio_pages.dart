import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../common/kliq_video.dart';
import '../discover/discover_common.dart';
import 'stremio_service.dart';

/// Netflix-style movie/series surfaces powered by the Stremio add-on
/// protocol (Cinemeta catalogues by default + any user-added add-ons).

class StremioPoster extends StatelessWidget {
  const StremioPoster({super.key, required this.meta, this.width = 112});

  final Map<String, dynamic> meta;
  final double width;

  @override
  Widget build(BuildContext context) {
    final poster = pickStr(meta, ['poster', 'background']);
    return GestureDetector(
      onTap: () => context.push(
          '/kliqstream/title/${meta['type']}/${Uri.encodeComponent(meta['id'].toString())}'),
      child: Container(
        width: width,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: width,
                  child: poster.isEmpty
                      ? const ColoredBox(
                          color: KliqColors.surfaceElevated,
                          child: Icon(Icons.movie_outlined,
                              color: KliqColors.textMuted))
                      : CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => const ColoredBox(
                              color: KliqColors.surface),
                          errorWidget: (c, u, e) => const ColoredBox(
                              color: KliqColors.surfaceElevated,
                              child: Icon(Icons.movie_outlined,
                                  color: KliqColors.textMuted)),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(pickStr(meta, ['name']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

/// A horizontal catalogue row fetched from a Stremio add-on.
class StremioRow extends StatefulWidget {
  const StremioRow(
      {super.key,
      required this.title,
      required this.type,
      required this.catalogId});

  final String title;
  final String type;
  final String catalogId;

  @override
  State<StremioRow> createState() => _StremioRowState();
}

class _StremioRowState extends State<StremioRow> {
  List<Map<String, dynamic>> _metas = [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    StremioClient.instance
        .catalog(widget.type, widget.catalogId)
        .then((m) => mounted ? setState(() => _metas = m) : null)
        .catchError((_) => mounted ? setState(() => _failed = true) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Text(widget.title,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 190,
          child: _metas.isEmpty
              ? const CenterSpinner()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _metas.length,
                  itemBuilder: (context, i) =>
                      StremioPoster(meta: _metas[i]),
                ),
        ),
      ],
    );
  }
}

/// Full-text movie/series search (Netflix-style grid).
class KliqStreamSearchPage extends StatefulWidget {
  const KliqStreamSearchPage({super.key});

  @override
  State<KliqStreamSearchPage> createState() => _KliqStreamSearchPageState();
}

class _KliqStreamSearchPageState extends State<KliqStreamSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await StremioClient.instance.search(q);
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: _search,
          decoration: const InputDecoration(
            hintText: 'Search movies & series',
            prefixIcon: Icon(Icons.search, color: KliqColors.textMuted),
          ),
        ),
      ),
      body: _searching
          ? const CenterSpinner()
          : !_searched
              ? const EmptyState(
                  icon: Icons.theaters_outlined,
                  title: 'Find something to watch',
                  subtitle: 'Search across movies and series')
              : _results.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off, title: 'No titles found')
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 130,
                        childAspectRatio: 0.62,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, i) =>
                          StremioPoster(meta: _results[i]),
                    ),
    );
  }
}

/// Title page: banner, synopsis, play button; for series a season/episode
/// picker built from the add-on's meta `videos`.
class StremioTitlePage extends StatefulWidget {
  const StremioTitlePage(
      {super.key, required this.type, required this.id});

  final String type;
  final String id;

  @override
  State<StremioTitlePage> createState() => _StremioTitlePageState();
}

class _StremioTitlePageState extends State<StremioTitlePage> {
  Map<String, dynamic>? _meta;
  bool _loading = true;
  String? _error;
  int _season = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final meta = await StremioClient.instance.meta(widget.type, widget.id);
      if (!mounted) return;
      final seasons = _seasons(meta);
      setState(() {
        _meta = meta;
        if (seasons.isNotEmpty) _season = seasons.first;
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

  List<Map<String, dynamic>> _videos(Map<String, dynamic> meta) =>
      (meta['videos'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  List<int> _seasons(Map<String, dynamic> meta) {
    final s = _videos(meta)
        .map((v) => (v['season'] as num?)?.toInt() ?? 0)
        .where((n) => n > 0)
        .toSet()
        .toList()
      ..sort();
    return s;
  }

  void _play(String videoId, String title) {
    context.push(
        '/kliqstream/play/${widget.type}/${Uri.encodeComponent(videoId)}?name=${Uri.encodeComponent(title)}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    if (_error != null || _meta == null) {
      return Scaffold(
          appBar: AppBar(),
          body: ErrorState(
              message: _error ?? 'Title not found', onRetry: _load));
    }
    final m = _meta!;
    final isSeries = widget.type == 'series';
    final seasons = _seasons(m);
    final episodes = _videos(m)
        .where((v) => ((v['season'] as num?)?.toInt() ?? 0) == _season)
        .toList()
      ..sort((a, b) => ((a['episode'] as num?)?.toInt() ?? 0)
          .compareTo((b['episode'] as num?)?.toInt() ?? 0));
    final banner = pickStr(m, ['background', 'poster']);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (banner.isNotEmpty)
                    CachedNetworkImage(imageUrl: banner, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.92)
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
                  Text(pickStr(m, ['name']),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (pickStr(m, ['imdbRating']).isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: KliqColors.warning),
                            const SizedBox(width: 3),
                            Text(pickStr(m, ['imdbRating']),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: KliqColors.textSecondary)),
                          ],
                        ),
                      Text(pickStr(m, ['releaseInfo', 'year']),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: KliqColors.textSecondary)),
                      Text(
                          ((m['genres'] as List?) ?? [])
                              .take(3)
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: KliqColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(pickStr(m, ['description']),
                      style: const TextStyle(
                          color: KliqColors.textSecondary,
                          fontSize: 13.5,
                          height: 1.5)),
                  const SizedBox(height: 16),
                  if (!isSeries)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: KliqColors.gradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          onPressed: () =>
                              _play(widget.id, pickStr(m, ['name'])),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Play',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    )
                  else if (seasons.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text('Episodes',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        DropdownButton<int>(
                          value: _season,
                          dropdownColor: KliqColors.surfaceElevated,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final s in seasons)
                              DropdownMenuItem(
                                  value: s, child: Text('Season $s')),
                          ],
                          onChanged: (v) =>
                              setState(() => _season = v ?? _season),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isSeries)
            SliverList.builder(
              itemCount: episodes.length,
              itemBuilder: (context, i) {
                final e = episodes[i];
                final thumb = pickStr(e, ['thumbnail']);
                final title = pickStr(e, ['name', 'title'],
                    fallback: 'Episode ${e['episode']}');
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 88,
                      height: 50,
                      child: thumb.isEmpty
                          ? const ColoredBox(
                              color: KliqColors.surfaceElevated)
                          : CachedNetworkImage(
                              imageUrl: thumb, fit: BoxFit.cover),
                    ),
                  ),
                  title: Text('${e['episode']}. $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.play_circle_outline,
                      color: KliqColors.cyan),
                  onTap: () => _play(e['id'].toString(), title),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// Resolves streams for a title from the registered add-ons and plays the
/// chosen one full-screen.
class StremioPlayerPage extends StatefulWidget {
  const StremioPlayerPage(
      {super.key, required this.type, required this.id, this.title});

  final String type;
  final String id;
  final String? title;

  @override
  State<StremioPlayerPage> createState() => _StremioPlayerPageState();
}

class _StremioPlayerPageState extends State<StremioPlayerPage> {
  List<Map<String, dynamic>> _streams = [];
  String? _playingUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streams =
        await StremioClient.instance.streams(widget.type, widget.id);
    if (!mounted) return;
    setState(() {
      _streams = streams;
      _loading = false;
      // Auto-play when there is exactly one option.
      if (streams.length == 1) {
        _playingUrl = streams.first['url']?.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(widget.title ?? 'Now Playing')),
      body: _loading
          ? const CenterSpinner()
          : _playingUrl != null
              ? Center(child: KliqVideo(url: _playingUrl!))
              : _streams.isEmpty
                  ? EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'No playable stream',
                      subtitle:
                          'None of your add-ons returned a direct stream '
                          'for this title. Add a streaming add-on you have '
                          'access to in the add-on manager.',
                      actionLabel: 'Manage add-ons',
                      onAction: () =>
                          context.push('/kliqstream/addons'))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Choose a source',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                        for (final s in _streams)
                          ListTile(
                            leading: const Icon(Icons.play_circle_fill,
                                color: KliqColors.cyan),
                            title: Text(
                                pickStr(s, ['name', 'title'],
                                    fallback: 'Stream'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5)),
                            subtitle: Text(
                                pickStr(s, ['addonName']),
                                style: const TextStyle(
                                    color: KliqColors.textMuted,
                                    fontSize: 11.5)),
                            onTap: () => setState(() =>
                                _playingUrl = s['url']?.toString()),
                          ),
                      ],
                    ),
    );
  }
}

/// Manage Stremio add-on URLs.
class StremioAddonsPage extends StatefulWidget {
  const StremioAddonsPage({super.key});

  @override
  State<StremioAddonsPage> createState() => _StremioAddonsPageState();
}

class _StremioAddonsPageState extends State<StremioAddonsPage> {
  final _url = TextEditingController();
  bool _adding = false;

  Future<void> _add() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await StremioClient.instance.addAddon(url);
      messenger.showSnackBar(SnackBar(content: Text('Added add-on: $name')));
      _url.clear();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not add add-on: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = StremioClient.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Streaming Add-ons')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'KliqStream speaks the Stremio add-on protocol. Cinemeta powers '
            'the movie & series catalogue; add the manifest URL of any '
            'stremio-addon-sdk add-on you have access to and its streams '
            'become playable here.',
            style: TextStyle(color: KliqColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _url,
                  decoration: const InputDecoration(
                      hintText: 'https://my-addon.example.com/manifest.json'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _adding ? null : _add,
                child: Text(_adding ? '…' : 'Add'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Installed',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final base in client.addons)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.extension_outlined,
                  color: KliqColors.cyan),
              title: Text(
                  base == StremioClient.cinemeta
                      ? 'Cinemeta (catalogue & metadata)'
                      : base,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5)),
              trailing: base == StremioClient.cinemeta
                  ? const Text('default',
                      style: TextStyle(
                          color: KliqColors.textMuted, fontSize: 11))
                  : IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: KliqColors.danger),
                      onPressed: () async {
                        await client.removeAddon(base);
                        setState(() {});
                      },
                    ),
            ),
        ],
      ),
    );
  }
}

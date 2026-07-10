import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'discover_common.dart';

/// Full-text search with Users / Posts / Communities tabs and persistent
/// recent searches (last 8, individually removable).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  Map<String, dynamic> _results = {};
  List<String> _recent = [];

  static const _recentKey = 'kliq.recentSearches';

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _recent = prefs.getStringList(_recentKey) ?? []);
    }
  }

  Future<void> _saveRecent(String q) async {
    _recent.remove(q);
    _recent.insert(0, q);
    if (_recent.length > 8) _recent = _recent.sublist(0, 8);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recent);
  }

  Future<void> _removeRecent(String q) async {
    setState(() => _recent.remove(q));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentKey, _recent);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      setState(() => _results = {});
      return;
    }
    setState(() => _searching = true);
    try {
      final data = await Api.instance.get('/search', query: {'q': q});
      if (!mounted) return;
      setState(() {
        _results = asMap(data);
        _searching = false;
      });
      _saveRecent(q);
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search KLIQ',
              prefixIcon:
                  const Icon(Icons.search, color: KliqColors.textMuted),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 18, color: KliqColors.textMuted),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _results = {});
                      },
                    )
                  : null,
            ),
          ),
          bottom: hasQuery
              ? const TabBar(
                  indicatorColor: KliqColors.cyan,
                  labelColor: KliqColors.textPrimary,
                  unselectedLabelColor: KliqColors.textMuted,
                  tabs: [
                    Tab(text: 'Users'),
                    Tab(text: 'Posts'),
                    Tab(text: 'Communities'),
                  ],
                )
              : null,
        ),
        body: !hasQuery
            ? _recentList()
            : _searching
                ? const CenterSpinner()
                : TabBarView(
                    children: [
                      _usersTab(),
                      _postsTab(),
                      _communitiesTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _recentList() {
    if (_recent.isEmpty) {
      return const EmptyState(
          icon: Icons.search,
          title: 'Search KLIQ',
          subtitle: 'Find creators, posts, hashtags and communities');
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            children: [
              const Text('Recent',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: _clearRecent,
                child: const Text('Clear all',
                    style: TextStyle(color: KliqColors.cyan, fontSize: 13)),
              ),
            ],
          ),
        ),
        for (final q in _recent)
          ListTile(
            leading:
                const Icon(Icons.history, color: KliqColors.textMuted),
            title: Text(q),
            trailing: IconButton(
              icon: const Icon(Icons.close,
                  size: 16, color: KliqColors.textMuted),
              onPressed: () => _removeRecent(q),
            ),
            onTap: () {
              _controller.text = q;
              _search(q);
            },
          ),
      ],
    );
  }

  Widget _usersTab() {
    final users = asMapList(_results['users'], key: 'users');
    if (users.isEmpty) {
      return const EmptyState(icon: Icons.person_search, title: 'No users found');
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        return ListTile(
          leading: KliqAvatar(u['avatarUrl']?.toString()),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(pickStr(u, ['displayName', 'username']),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (u['isVerified'] == true) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 14, color: KliqColors.cyan),
              ],
            ],
          ),
          subtitle: Text('@${pickStr(u, ['username'])}',
              style: const TextStyle(color: KliqColors.textMuted)),
          onTap: () => context.push('/user/${pickStr(u, ['username'])}'),
        );
      },
    );
  }

  Widget _postsTab() {
    final posts = asMapList(_results['posts']);
    if (posts.isEmpty) {
      return const EmptyState(icon: Icons.grid_off, title: 'No posts found');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final p = posts[i];
        final media = p['mediaUrls'] is List && (p['mediaUrls'] as List).isNotEmpty
            ? (p['mediaUrls'] as List).first.toString()
            : null;
        return GestureDetector(
          onTap: () => context.push('/post/${p['id']}'),
          child: media != null
              ? NetImg(media)
              : Container(
                  color: KliqColors.surfaceElevated,
                  padding: const EdgeInsets.all(8),
                  child: Text(p['body']?.toString() ?? '',
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
        );
      },
    );
  }

  Widget _communitiesTab() {
    final comms = asMapList(_results['communities'], key: 'communities');
    if (comms.isEmpty) {
      return const EmptyState(
          icon: Icons.groups_outlined, title: 'No communities found');
    }
    return ListView.builder(
      itemCount: comms.length,
      itemBuilder: (context, i) {
        final c = comms[i];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
                width: 44, height: 44, child: NetImg(c['avatarUrl']?.toString())),
          ),
          title: Text(pickStr(c, ['name']),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${fmtCount(pickInt(c, ['memberCount']))} members',
              style: const TextStyle(color: KliqColors.textMuted)),
          onTap: () => context.push('/community/${c['id']}'),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';
import '../home/feed_models.dart';

/// Profile surface used for both the signed-in user (the Profile tab,
/// [username] == null) and other creators (/user/:username).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.username});

  final String? username;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  List<Post> _posts = [];
  List<Post> _reels = [];
  List<Post> _reposts = [];
  bool _loading = true;
  bool _following = false;
  String? _error;

  bool get _isOwn => widget.username == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = context.read<Session>();
      final key = widget.username ?? session.userId;
      final data = _isOwn
          ? await Api.instance.get('/auth/me')
          : await Api.instance.get('/users/$key');
      final user = asMap(data);
      // The user content endpoints key on USERNAME, not id.
      final uname = user['username']?.toString() ?? '';
      final lists = await Future.wait([
        _fetchList('/users/$uname/posts', query: {'type': 'post'}),
        _fetchList('/users/$uname/posts', query: {'type': 'reel'}),
        _fetchList('/users/$uname/reposts'),
      ]);
      if (!mounted) return;
      setState(() {
        _user = user;
        _posts = lists[0];
        _reels = lists[1];
        _reposts = lists[2];
        _following = user['isFollowing'] == true;
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

  Future<List<Post>> _fetchList(String path,
      {Map<String, dynamic>? query}) async {
    try {
      return parsePostList(await Api.instance.get(path, query: query));
    } catch (_) {
      return [];
    }
  }

  Future<void> _toggleFollow() async {
    final id = _user?['id']?.toString();
    if (id == null) return;
    setState(() {
      _following = !_following;
      final delta = _following ? 1 : -1;
      _user!['followerCount'] =
          (pickInt(_user!, ['followerCount']) + delta).clamp(0, 1 << 31);
    });
    try {
      await Api.instance.post('/users/$id/follow');
    } catch (_) {
      setState(() => _following = !_following);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    if (_error != null || _user == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: _error ?? 'Profile not found', onRetry: _load),
      );
    }

    final u = _user!;
    final username = pickStr(u, ['username']);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(username,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            if (u['isVerified'] == true) ...[
              const SizedBox(width: 5),
              const Icon(Icons.verified, size: 17, color: KliqColors.cyan),
            ],
          ],
        ),
        actions: [
          if (_isOwn) ...[
            IconButton(
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () => context.go('/create')),
            IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Settings',
                onPressed: () => context.push('/settings')),
          ],
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: RefreshIndicator(
          color: KliqColors.cyan,
          onRefresh: _load,
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(child: _header(u)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeader(
                  const TabBar(
                    indicatorColor: KliqColors.textPrimary,
                    labelColor: KliqColors.textPrimary,
                    unselectedLabelColor: KliqColors.textMuted,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on_outlined, size: 20)),
                      Tab(icon: Icon(Icons.movie_creation_outlined, size: 20)),
                      Tab(icon: Icon(Icons.repeat, size: 20)),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _grid(_posts, 'No posts yet'),
                _grid(_reels, 'No reels yet'),
                _grid(_reposts, 'No reposts yet'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> u) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, gradient: KliqColors.storyRing),
                padding: const EdgeInsets.all(2.5),
                child: ClipOval(
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: NetImg(u['avatarUrl']?.toString()),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(formatCount(pickInt(u, ['postCount'])), 'Posts'),
                    _stat(formatCount(pickInt(u, ['followerCount'])),
                        'Followers'),
                    _stat(formatCount(pickInt(u, ['followingCount'])),
                        'Following'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(pickStr(u, ['displayName', 'username']),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (pickStr(u, ['bio']).isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(pickStr(u, ['bio']),
                style: const TextStyle(
                    color: KliqColors.textSecondary, fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          Row(
            children: _isOwn
                ? [
                    _actionButton('Edit Profile',
                        onTap: () => context.push('/edit-profile')),
                    const SizedBox(width: 8),
                    _actionButton('Share Profile',
                        onTap: () => context.push('/settings')),
                  ]
                : [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _following ? null : KliqColors.gradient,
                          color: _following
                              ? KliqColors.surfaceElevated
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          onPressed: _toggleFollow,
                          child: Text(
                            _following ? 'Following' : 'Follow',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionButton('Message', onTap: () {
                      final id = _user?['id']?.toString() ?? '';
                      context.push('/chat/$id');
                    }),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: KliqColors.textSecondary, fontSize: 12.5)),
      ],
    );
  }

  Widget _actionButton(String label, {required VoidCallback onTap}) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: KliqColors.textPrimary,
          side: const BorderSide(color: KliqColors.border),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: onTap,
        child: Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _grid(List<Post> posts, String emptyLabel) {
    return CustomScrollView(
      key: PageStorageKey(emptyLabel),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (posts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.grid_on_outlined,
              title: emptyLabel,
              subtitle: 'Content will appear here',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(1),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final p = posts[i];
                return GestureDetector(
                  onTap: () => context.push('/post/${p.id}'),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      p.isText
                          ? Container(
                              color: KliqColors.surfaceElevated,
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                p.body,
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            )
                          : NetImg(p.mediaUrls.isNotEmpty ? p.mediaUrls.first : ''),
                      if (!p.isText && p.mediaType == 'video')
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(Icons.play_arrow,
                              size: 18, color: Colors.white),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Pinned tab bar between the profile header and the content grids.
class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader(this.tabBar);
  final TabBar tabBar;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: KliqColors.background, child: tabBar);

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarHeader oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart' hide timeAgo;
import 'feed_models.dart';
import 'widgets/post_card.dart';

/// Notifications, Saved posts, Friends and Hashtag pages.

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/notifications');
      final list = data is Map && data['notifications'] is List
          ? data['notifications'] as List
          : (data is List ? data : const []);
      if (!mounted) return;
      setState(() {
        _items = list
            .whereType<Map>()
            .map((e) => AppNotification.fromJson(e.cast<String, dynamic>()))
            .toList();
        _loading = false;
      });
      Api.instance.post('/notifications/read-all').catchError((_) => null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  IconData _icon(String type) => switch (type) {
        'like' => Icons.favorite,
        'follow' => Icons.person_add,
        'comment' => Icons.chat_bubble,
        'gift' => Icons.card_giftcard,
        'sale' => Icons.shopping_bag,
        _ => Icons.notifications,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const CenterSpinner()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none,
                      title: 'Nothing yet',
                      subtitle:
                          'Likes, comments and follows will appear here')
                  : RefreshIndicator(
                      color: KliqColors.cyan,
                      onRefresh: _load,
                      child: ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final n = _items[i];
                          return ListTile(
                            tileColor: n.read
                                ? null
                                : KliqColors.cyan.withValues(alpha: 0.05),
                            leading: Stack(
                              children: [
                                KliqAvatar(n.actorAvatar, radius: 20),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Icon(_icon(n.type),
                                      size: 13, color: KliqColors.pink),
                                ),
                              ],
                            ),
                            title: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: n.actorName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                TextSpan(text: ' ${n.message}'),
                              ]),
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            subtitle: Text(timeAgo(n.createdAt),
                                style: const TextStyle(
                                    color: KliqColors.textMuted,
                                    fontSize: 11.5)),
                            onTap: () {
                              if (n.actorUsername != null &&
                                  (n.type == 'follow')) {
                                context.push('/user/${n.actorUsername}');
                              } else if (n.targetId != null) {
                                context.push('/post/${n.targetId}');
                              }
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/bookmarks');
      if (!mounted) return;
      setState(() {
        _posts = parsePostList(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: _loading
          ? const CenterSpinner()
          : _posts.isEmpty
              ? const EmptyState(
                  icon: Icons.bookmark_border,
                  title: 'No saved posts',
                  subtitle: 'Tap the bookmark icon on any post to save it')
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, i) => PostCard(
                      post: _posts[i],
                      gradientSeed: i,
                      onChanged: _load),
                ),
    );
  }
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = context.read<Session>().userId;
    try {
      final results = await Future.wait([
        Api.instance.get('/users/$id/followers').catchError((_) => []),
        Api.instance.get('/users/$id/following').catchError((_) => []),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = asMapList(results[0], key: 'users');
        _following = asMapList(results[1], key: 'users');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _list(List<Map<String, dynamic>> users, String emptyLabel) {
    if (users.isEmpty) {
      return EmptyState(icon: Icons.people_outline, title: emptyLabel);
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, i) {
        final u = users[i];
        return ListTile(
          leading: KliqAvatar(u['avatarUrl']?.toString()),
          title: Text(pickStr(u, ['displayName', 'username']),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('@${pickStr(u, ['username'])}',
              style: const TextStyle(color: KliqColors.textMuted)),
          onTap: () => context.push('/user/${pickStr(u, ['username'])}'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: TabBar(
            indicatorColor: KliqColors.cyan,
            labelColor: KliqColors.textPrimary,
            unselectedLabelColor: KliqColors.textMuted,
            tabs: [
              Tab(text: 'Followers (${_followers.length})'),
              Tab(text: 'Following (${_following.length})'),
            ],
          ),
        ),
        body: _loading
            ? const CenterSpinner()
            : TabBarView(children: [
                _list(_followers, 'No followers yet'),
                _list(_following, 'Not following anyone yet'),
              ]),
      ),
    );
  }
}

class HashtagPage extends StatefulWidget {
  const HashtagPage({super.key, required this.tag});

  final String tag;

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/hashtags/${widget.tag}/posts');
      if (!mounted) return;
      setState(() {
        _posts = parsePostList(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.tag}')),
      body: _loading
          ? const CenterSpinner()
          : _posts.isEmpty
              ? const EmptyState(
                  icon: Icons.tag, title: 'No posts with this hashtag yet')
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2),
                  itemCount: _posts.length,
                  itemBuilder: (context, i) {
                    final p = _posts[i];
                    return GestureDetector(
                      onTap: () => context.push('/post/${p.id}'),
                      child: p.isText
                          ? Container(
                              color: KliqColors.surfaceElevated,
                              padding: const EdgeInsets.all(8),
                              child: Text(p.body,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                            )
                          : NetImg(p.mediaUrls.first),
                    );
                  },
                ),
    );
  }
}

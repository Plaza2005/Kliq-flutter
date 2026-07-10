import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'demo_store.dart';

/// Answers API calls in demo mode with data from [DemoStore], simulating the
/// Node server's routes. Firebase/Supabase/network are never touched.
///
/// Handlers cover the core surface; unknown GETs return an empty list and
/// unknown mutations return `{ok: true}` so no screen can crash on a missing
/// route. Feature teams extend [_handleGet]/[_handleMutation] as they build.
class DemoBackend {
  DemoBackend._();
  static final instance = DemoBackend._();

  DemoStore get store => DemoStore.instance;
  final _rng = Random();

  Future<dynamic> handle(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    // Simulate a small network latency so the UI's loading states render.
    await Future.delayed(Duration(milliseconds: 80 + _rng.nextInt(120)));
    final p = path.split('?').first;
    final b = (body is Map<String, dynamic>) ? body : <String, dynamic>{};
    try {
      if (method == 'GET') return _handleGet(p, query ?? {});
      return _handleMutation(method, p, b);
    } catch (e) {
      debugPrint('[demo] $method $p failed: $e');
      return method == 'GET' ? [] : {'ok': true};
    }
  }

  dynamic handleUpload(String path, String filename) {
    // Pretend the file landed in /uploads; hand back a stable demo image.
    return {'url': DemoStore.img(9000 + _rng.nextInt(999))};
  }

  // ── GET ───────────────────────────────────────────────────────────────
  dynamic _handleGet(String p, Map<String, dynamic> query) {
    final s = store;
    final seg = p.split('/').where((x) => x.isNotEmpty).toList();

    if (p == '/auth/me' || p == '/users/me') return s.me;
    if (p == '/posts/feed' || p == '/posts') {
      return s.posts
          .map((post) => {
                ...post,
                'isLiked': s.likedPostIds.contains(post['id']),
                'isSaved': s.savedPostIds.contains(post['id']),
              })
          .toList();
    }
    if (p == '/stories' || p == '/stories/feed') return s.stories;
    if (p == '/search/trending') {
      return [
        {'tag': 'namibia', 'postCount': 1240},
        {'tag': 'windhoek', 'postCount': 860},
        {'tag': 'kliq', 'postCount': 745},
        {'tag': 'music', 'postCount': 512},
        {'tag': 'food', 'postCount': 431},
        {'tag': 'wildlife', 'postCount': 322},
      ];
    }
    if (p == '/posts/reels' || p == '/reels') return s.reels;
    if (p == '/posts/explore' || p == '/explore') {
      return [...s.posts]..shuffle(_rng);
    }
    if (p == '/live/streams') return s.liveStreams.where((l) => l['isLive'] == true).toList();
    if (p == '/kliqtube' || p == '/tube') return s.tubeVideos;
    if (p == '/kliqstream' || p == '/kliqstream/catalogue') {
      return {
        'featured': s.streamShows.take(3).toList(),
        'trending': s.streamShows,
        'categories': {
          for (final show in s.streamShows)
            (show['category'] as String): s.streamShows
                .where((x) => x['category'] == show['category'])
                .toList(),
        },
      };
    }
    if (p == '/kliqstream/mylist') {
      return s.streamShows.where((x) => x['inMyList'] == true).toList();
    }
    if (p == '/kliqtube/playlists') {
      return [
        {
          'id': 'pl_demo_0',
          'title': 'Watch Later',
          'thumbnailUrl': DemoStore.img(310, w: 640, h: 360),
          'videoCount': 4,
        },
        {
          'id': 'pl_demo_1',
          'title': 'Music Production',
          'thumbnailUrl': DemoStore.img(311, w: 640, h: 360),
          'videoCount': 7,
        },
      ];
    }
    if (p == '/sounds') {
      return [
        for (var i = 0; i < 8; i++)
          {
            'id': 'snd_demo_$i',
            'name': [
              'Kalahari Nights', 'Windhoek Groove', 'Desert Rose',
              'Coastal Vibes', 'Township Funk', 'Savanna Beat',
              'Etosha Dawn', 'Kwaito Flow'
            ][i],
            'artist': s.users[i % s.users.length]['displayName'],
            'useCount': 120 + i * 340,
          }
      ];
    }
    if (p == '/marketplace/products' || p == '/marketplace') return s.products;
    if (p == '/wallet') return {...s.wallet, 'transactions': s.walletTransactions};
    if (p == '/wallet/history') return s.walletTransactions;
    if (p == '/notifications') return s.notifications;
    if (p == '/messages/conversations') return s.conversations;
    if (p == '/communities') return s.communities;
    if (p == '/search') {
      final q = (query['q'] ?? '').toString().toLowerCase();
      if (q.isEmpty) return {'users': [], 'posts': [], 'communities': []};
      return {
        'users': s.users
            .where((u) =>
                u['username'].toString().contains(q) ||
                u['displayName'].toString().toLowerCase().contains(q))
            .toList(),
        'posts': s.posts
            .where((post) => post['body'].toString().toLowerCase().contains(q))
            .toList(),
        'communities': s.communities
            .where((c) => c['name'].toString().toLowerCase().contains(q))
            .toList(),
      };
    }

    if (p == '/users/suggestions') {
      return s.users.where((u) => !s.followedUserIds.contains(u['id'])).toList();
    }
    if (p == '/bookmarks') {
      return s.posts
          .where((post) => s.savedPostIds.contains(post['id']))
          .map((post) => {...post, 'isSaved': true})
          .toList();
    }

    // Parameterised routes.
    if (seg.length >= 2) {
      if (seg[0] == 'hashtags' && seg.length >= 2) {
        final tag = seg[1].toLowerCase();
        return s.posts
            .where((post) =>
                post['body'].toString().toLowerCase().contains('#$tag'))
            .toList();
      }
      if (seg[0] == 'users' && seg.length >= 3 &&
          (seg[2] == 'followers' || seg[2] == 'following')) {
        return seg[2] == 'followers'
            ? s.users.take(6).toList()
            : s.users
                .where((u) => s.followedUserIds.contains(u['id']))
                .toList();
      }
      switch (seg[0]) {
        case 'users':
          final u = s.findUser(seg[1]);
          if (u == null) break;
          if (seg.length >= 3 && seg[2] == 'posts') {
            return s.posts.where((post) => post['author']['id'] == u['id']).toList();
          }
          return {...u, 'isFollowing': s.followedUserIds.contains(u['id'])};
        case 'posts':
          if (seg.length >= 3 && seg[2] == 'comments') {
            return s.comments[seg[1]] ?? [];
          }
          final post = s.posts.where((x) => x['id'] == seg[1]).firstOrNull;
          if (post != null) return post;
          break;
        case 'kliqtube':
        case 'tube':
          final v = s.tubeVideos.where((x) => x['id'] == seg[1]).firstOrNull;
          if (v != null) return v;
          break;
        case 'kliqstream':
          final show = s.streamShows.where((x) => x['id'] == seg[1]).firstOrNull;
          if (show != null) return show;
          break;
        case 'marketplace':
          final prod = s.products.where((x) => x['id'] == seg[1]).firstOrNull;
          if (prod != null) return prod;
          break;
        case 'messages':
          return s.messages[seg[1]] ?? [];
        case 'communities':
          final c = s.communities.where((x) => x['id'] == seg[1]).firstOrNull;
          if (c != null) return c;
          break;
      }
    }

    debugPrint('[demo] unhandled GET $p — returning []');
    return [];
  }

  // ── Mutations ──────────────────────────────────────────────────────────
  dynamic _handleMutation(String method, String p, Map<String, dynamic> body) {
    final s = store;
    final seg = p.split('/').where((x) => x.isNotEmpty).toList();

    if (p == '/auth/login' || p == '/auth/register') {
      return {'token': 'demo-token', 'user': s.me};
    }
    if (p == '/auth/me' && (method == 'PATCH' || method == 'PUT')) {
      s.me.addAll(body);
      return s.me;
    }
    if (p == '/stories' && method == 'POST') {
      final story = {
        'id': s.nextId('s'),
        'author': s.me,
        'items': [
          {
            'id': s.nextId('si'),
            'mediaUrl': body['mediaUrl'] ?? DemoStore.img(9500),
            'mediaType': body['mediaType'] ?? 'image',
            'createdAt': DateTime.now().toIso8601String(),
          }
        ],
        'seen': false,
      };
      s.stories.insert(0, story);
      return story;
    }
    if (p == '/notifications/read-all') {
      for (final n in s.notifications) {
        n['read'] = true;
      }
      return {'ok': true};
    }
    if (p == '/posts' && method == 'POST') {
      final post = {
        'id': s.nextId('p'),
        'author': s.me,
        'body': body['body'] ?? '',
        'mediaUrls': body['mediaUrls'] ?? <String>[],
        'mediaType': body['mediaType'] ?? 'text',
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
        'isLiked': false,
        'isSaved': false,
        'location': body['location'],
        'createdAt': DateTime.now().toIso8601String(),
      };
      s.posts.insert(0, post);
      return post;
    }

    if (seg.length >= 3 && seg[0] == 'posts') {
      final id = seg[1];
      final post = s.posts.where((x) => x['id'] == id).firstOrNull;
      switch (seg[2]) {
        case 'like':
          if (s.likedPostIds.contains(id)) {
            s.likedPostIds.remove(id);
            if (post != null) post['likeCount'] = (post['likeCount'] as int) - 1;
          } else {
            s.likedPostIds.add(id);
            if (post != null) post['likeCount'] = (post['likeCount'] as int) + 1;
          }
          return {'liked': s.likedPostIds.contains(id)};
        case 'save':
        case 'bookmark':
          s.savedPostIds.contains(id)
              ? s.savedPostIds.remove(id)
              : s.savedPostIds.add(id);
          return {'saved': s.savedPostIds.contains(id)};
        case 'comments':
          final comment = {
            'id': s.nextId('c'),
            'author': s.me,
            'body': body['body'] ?? '',
            'likeCount': 0,
            'createdAt': DateTime.now().toIso8601String(),
          };
          s.comments.putIfAbsent(id, () => []).add(comment);
          if (post != null) {
            post['commentCount'] = (post['commentCount'] as int) + 1;
          }
          return comment;
      }
    }

    if (seg.length >= 3 && seg[0] == 'users' && seg[2] == 'follow') {
      final id = seg[1];
      s.followedUserIds.contains(id)
          ? s.followedUserIds.remove(id)
          : s.followedUserIds.add(id);
      return {'following': s.followedUserIds.contains(id)};
    }

    if (p == '/live/start') {
      final stream = {
        'id': s.nextId('live'),
        'title': body['title'] ?? 'Live on KLIQ',
        'category': body['category'] ?? 'Entertainment',
        'thumbnailUrl': body['thumbnailUrl'],
        'viewerCount': 0,
        'startedAt': DateTime.now().toIso8601String(),
        'isLive': true,
        'user': s.me,
      };
      s.liveStreams.insert(0, stream);
      return {'streamId': stream['id'], 'streamKey': 'demo-stream-key'};
    }
    if (p == '/live/end') {
      for (final l in s.liveStreams) {
        if (l['user']['id'] == s.me['id']) l['isLive'] = false;
      }
      return {'ended': true};
    }
    if (seg.length >= 3 && seg[0] == 'live') {
      final stream = s.liveStreams.where((x) => x['id'] == seg[1]).firstOrNull;
      if (seg[2] == 'view') {
        if (stream != null) {
          stream['viewerCount'] = (stream['viewerCount'] as int) + 1;
          return {'viewerCount': stream['viewerCount']};
        }
        return {'viewerCount': 1};
      }
      if (seg[2] == 'gift') {
        const costs = {'rose': 1, 'heart': 5, 'star': 10, 'diamond': 50, 'crown': 100, 'rocket': 200};
        final coins = costs[body['giftType']] ?? 1;
        s.wallet['tokens'] = (s.wallet['tokens'] as int) - coins;
        return {'ok': true, 'coins': coins};
      }
    }

    if (p == '/messages/send' ||
        (seg.length >= 2 && seg[0] == 'messages' && method == 'POST')) {
      final convId = seg.length >= 2 ? seg[1] : (body['conversationId'] ?? '');
      final msg = {
        'id': s.nextId('m'),
        'senderId': s.me['id'],
        'body': body['body'] ?? '',
        'createdAt': DateTime.now().toIso8601String(),
      };
      s.messages.putIfAbsent(convId.toString(), () => []).add(msg);
      return msg;
    }

    if (seg.length >= 3 && seg[0] == 'kliqstream' && seg[2] == 'mylist') {
      final show = s.streamShows.where((x) => x['id'] == seg[1]).firstOrNull;
      if (show != null) show['inMyList'] = !(show['inMyList'] as bool? ?? false);
      return {'inMyList': show?['inMyList'] ?? true};
    }
    if (seg.length >= 3 && seg[0] == 'kliqtube' && seg[2] == 'view') {
      final v = s.tubeVideos.where((x) => x['id'] == seg[1]).firstOrNull;
      if (v != null) v['viewCount'] = (v['viewCount'] as int) + 1;
      return {'ok': true};
    }

    if (seg.length >= 3 && seg[0] == 'communities' && seg[2] == 'join') {
      final c = s.communities.where((x) => x['id'] == seg[1]).firstOrNull;
      if (c != null) c['isJoined'] = !(c['isJoined'] as bool);
      return {'joined': c?['isJoined'] ?? true};
    }

    if (p == '/auth/logout') return {'ok': true};

    debugPrint('[demo] unhandled $method $p — returning {ok:true}');
    return {'ok': true};
  }

  // ── Demo realtime simulation ───────────────────────────────────────────
  StreamController<Map<String, dynamic>>? _ws;
  Timer? _liveSimTimer;
  String? _activeStreamId;

  static const _demoChatters = ['ndapewa', 'dj_kavango', 'swakop_surfer', 'kuku_fashion', 'nam_wildlife'];
  static const _demoChats = [
    'This is fire 🔥',
    'Greetings from Swakop! 🌊',
    'Loving the stream!',
    'First time catching you live 👋',
    'Play that track again 🎵',
    'Legend! 🙌',
    'How long are you live for?',
    '🇳🇦🇳🇦🇳🇦',
  ];

  void attachWs(StreamController<Map<String, dynamic>> events) {
    _ws = events;
    events.add({'type': 'connected', 'userId': store.me['id']});
  }

  void detachWs() {
    _liveSimTimer?.cancel();
    _liveSimTimer = null;
    _ws = null;
    _activeStreamId = null;
  }

  void handleWsSend(
      Map<String, dynamic> msg, StreamController<Map<String, dynamic>> events) {
    _ws = events;
    switch (msg['type']) {
      case 'stream:subscribe':
        _activeStreamId = msg['streamId'] as String?;
        _startLiveSim();
      case 'stream:unsubscribe':
        _liveSimTimer?.cancel();
        _liveSimTimer = null;
        _activeStreamId = null;
      case 'stream:chunk':
        // Loop the broadcaster's chunk back so viewer surfaces can render it.
        events.add({
          'type': 'live:chunk',
          'streamId': msg['streamId'],
          'chunk': msg['chunk'],
        });
        _activeStreamId = msg['streamId'] as String?;
        _startLiveSim();
      case 'live:chat':
        events.add({
          'type': 'live:chat',
          'streamId': msg['streamId'],
          'body': msg['body'],
          'fromUsername': msg['fromUsername'] ?? store.me['username'],
        });
    }
  }

  /// Fake audience: periodic chat messages, gifts and viewer-count changes.
  void _startLiveSim() {
    if (_liveSimTimer != null) return;
    _liveSimTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final ws = _ws;
      final streamId = _activeStreamId;
      if (ws == null || streamId == null) return;
      final roll = _rng.nextInt(10);
      if (roll < 6) {
        ws.add({
          'type': 'live:chat',
          'streamId': streamId,
          'body': _demoChats[_rng.nextInt(_demoChats.length)],
          'fromUsername': _demoChatters[_rng.nextInt(_demoChatters.length)],
        });
      } else if (roll < 8) {
        const gifts = ['rose', 'heart', 'star', 'diamond'];
        final gift = gifts[_rng.nextInt(gifts.length)];
        ws.add({
          'type': 'live:gift',
          'streamId': streamId,
          'giftType': gift,
          'coins': {'rose': 1, 'heart': 5, 'star': 10, 'diamond': 50}[gift],
          'sender': {
            'username': _demoChatters[_rng.nextInt(_demoChatters.length)],
          },
        });
      } else {
        ws.add({
          'type': 'live:viewers',
          'streamId': streamId,
          'viewerCount': 40 + _rng.nextInt(300),
        });
      }
    });
  }
}

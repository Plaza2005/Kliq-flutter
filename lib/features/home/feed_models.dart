import 'package:intl/intl.dart';

/// Normalised data models for the feed/profile surfaces.
///
/// The live Node API and the demo backend return slightly different JSON
/// shapes (e.g. `liked` vs `isLiked`, `mediaUrl` vs `mediaUrls`,
/// `{posts: [...]}` vs a plain list). These models absorb both so pages
/// have one code path.

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

int _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : 0);

DateTime _asDate(dynamic v) =>
    DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

class PostAuthor {
  PostAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  factory PostAuthor.fromJson(Map<String, dynamic> json) => PostAuthor(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        displayName: json['displayName']?.toString() ??
            json['username']?.toString() ??
            '',
        avatarUrl: json['avatarUrl']?.toString(),
        isVerified: json['isVerified'] == true,
      );
}

class Post {
  Post({
    required this.id,
    required this.author,
    required this.body,
    required this.mediaUrls,
    required this.mediaType,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.liked,
    required this.saved,
    required this.createdAt,
    this.location,
  });

  final String id;
  final PostAuthor author;
  final String body;
  final List<String> mediaUrls;
  final String mediaType;
  int likeCount;
  int commentCount;
  final int shareCount;
  bool liked;
  bool saved;
  final DateTime createdAt;
  final String? location;

  bool get isText => mediaUrls.isEmpty;

  factory Post.fromJson(Map<String, dynamic> json) {
    final media = <String>[];
    final carousel = json['carouselMedia'];
    final urls = json['mediaUrls'];
    if (carousel is List && carousel.isNotEmpty) {
      media.addAll(carousel.map((e) => e.toString()));
    } else if (urls is List && urls.isNotEmpty) {
      media.addAll(urls.map((e) => e.toString()));
    } else if (json['mediaUrl'] is String &&
        (json['mediaUrl'] as String).isNotEmpty) {
      media.add(json['mediaUrl'] as String);
    }
    return Post(
      id: json['id']?.toString() ?? '',
      author: PostAuthor.fromJson(_asMap(json['author'])),
      body: json['body']?.toString() ?? '',
      mediaUrls: media,
      mediaType: json['mediaType']?.toString() ??
          (media.isEmpty ? 'text' : 'image'),
      likeCount: _asInt(json['likeCount']),
      commentCount: _asInt(json['commentCount']),
      shareCount: _asInt(json['shareCount']),
      liked: json['liked'] == true || json['isLiked'] == true,
      saved: json['bookmarked'] == true || json['isSaved'] == true,
      createdAt: _asDate(json['createdAt']),
      location: json['location']?.toString(),
    );
  }
}

/// Parses a feed response that may be `{posts: [...], hasMore: bool}` (live)
/// or a plain list (demo).
({List<Post> posts, bool hasMore}) parseFeed(dynamic data) {
  List raw;
  bool hasMore = false;
  if (data is Map && data['posts'] is List) {
    raw = data['posts'] as List;
    hasMore = data['hasMore'] == true;
  } else if (data is List) {
    raw = data;
  } else {
    raw = const [];
  }
  return (
    posts: raw.whereType<Map>().map((e) => Post.fromJson(_asMap(e))).toList(),
    hasMore: hasMore,
  );
}

List<Post> parsePostList(dynamic data) => parseFeed(data).posts;

class PostComment {
  PostComment({
    required this.id,
    required this.author,
    required this.body,
    required this.likeCount,
    required this.createdAt,
    required this.replies,
  });

  final String id;
  final PostAuthor author;
  final String body;
  final int likeCount;
  final DateTime createdAt;
  final List<PostComment> replies;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: json['id']?.toString() ?? '',
        author: PostAuthor.fromJson(_asMap(json['author'])),
        body: json['body']?.toString() ?? '',
        likeCount: _asInt(json['likeCount']),
        createdAt: _asDate(json['createdAt']),
        replies: (json['replies'] is List)
            ? (json['replies'] as List)
                .whereType<Map>()
                .map((e) => PostComment.fromJson(_asMap(e)))
                .toList()
            : const [],
      );
}

class StorySlide {
  StorySlide({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    this.body,
    required this.createdAt,
  });

  final String id;
  final String mediaUrl;
  final String mediaType;
  final String? body;
  final DateTime createdAt;

  factory StorySlide.fromJson(Map<String, dynamic> json) => StorySlide(
        id: json['id']?.toString() ?? '',
        mediaUrl: json['mediaUrl']?.toString() ?? '',
        mediaType: json['mediaType']?.toString() ?? 'image',
        body: json['body']?.toString(),
        createdAt: _asDate(json['createdAt']),
      );
}

class StoryGroup {
  StoryGroup({
    required this.userId,
    required this.author,
    required this.slides,
    required this.seen,
  });

  final String userId;
  final PostAuthor author;
  final List<StorySlide> slides;
  final bool seen;

  /// Accepts both the live `/stories/feed` shape
  /// (`{userId, author, stories, hasViewed}`) and the demo `/stories`
  /// shape (`{id, author, items, seen}`).
  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    final author = PostAuthor.fromJson(_asMap(json['author']));
    final rawSlides = (json['stories'] ?? json['items']) as List? ?? const [];
    return StoryGroup(
      userId: json['userId']?.toString() ??
          (author.id.isNotEmpty ? author.id : author.username),
      author: author,
      slides: rawSlides
          .whereType<Map>()
          .map((e) => StorySlide.fromJson(_asMap(e)))
          .toList(),
      seen: json['hasViewed'] == true || json['seen'] == true,
    );
  }
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    this.actorUsername,
    this.actorAvatar,
    required this.message,
    this.targetId,
    this.targetType,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String actorName;
  final String? actorUsername;
  final String? actorAvatar;
  final String message;
  final String? targetId;
  final String? targetType;
  final bool read;
  final DateTime createdAt;

  /// Accepts both the live shape (`actorName`/`actorAvatar`/`readAt`) and the
  /// demo shape (`actor: {...}`, `read`).
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = _asMap(json['actor']);
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'activity',
      actorName: json['actorName']?.toString() ??
          actor['displayName']?.toString() ??
          actor['username']?.toString() ??
          'Someone',
      actorUsername:
          json['actorUsername']?.toString() ?? actor['username']?.toString(),
      actorAvatar:
          json['actorAvatar']?.toString() ?? actor['avatarUrl']?.toString(),
      message: json['message']?.toString() ?? '',
      targetId: json['targetId']?.toString(),
      targetType: json['targetType']?.toString(),
      read: json['readAt'] != null || json['read'] == true,
      createdAt: _asDate(json['createdAt']),
    );
  }
}

/// "3.4K" style compact counts.
String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

/// Instagram-style relative timestamps; falls back to a date for old posts.
String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 365) return DateFormat.MMMd().format(date);
  return DateFormat.yMMMd().format(date);
}

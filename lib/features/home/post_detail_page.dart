import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../common/comments_sheet.dart';
import '../discover/discover_common.dart' show CenterSpinner, ErrorState;
import 'feed_models.dart';
import 'widgets/post_card.dart';

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

/// Post page: the full post card plus its comment thread and a composer.
/// Renders the thread inline (full-page context) using the same
/// [CommentTile]/[CommentComposer] widgets the comments bottom-sheet uses,
/// so there is a single implementation of comment-tile rendering.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Post? _post;
  final _comments = <PostComment>[];
  final _seenIds = <String>{};
  final _expandedIds = <String>{};
  final _repliesLoading = <String>{};
  PostComment? _replyTarget;
  bool _loading = true;
  String? _error;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _wsSub = WsService.instance.events.listen(_onWsEvent);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await Api.instance.get('/posts/${widget.postId}');
      final comments =
          await Api.instance.get('/posts/${widget.postId}/comments');
      if (!mounted) return;
      final parsedComments = (comments is List ? comments : const [])
          .whereType<Map>()
          .map((e) => PostComment.fromJson(e.cast<String, dynamic>()))
          .toList();
      _seenIds.clear();
      for (final c in parsedComments) {
        _seenIds.add(c.id);
        for (final r in c.replies) {
          _seenIds.add(r.id);
        }
      }
      setState(() {
        _post = Post.fromJson((post as Map).cast<String, dynamic>());
        _comments
          ..clear()
          ..addAll(parsedComments);
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

  void _onWsEvent(Map<String, dynamic> e) {
    if (e['type'] != 'post:comment') return;
    if (e['postId']?.toString() != widget.postId) return;
    final map = _asMap(e['comment']);
    final id = map['id']?.toString();
    if (id == null || id.isEmpty || !_seenIds.add(id)) return;
    _applyNewComment(PostComment.fromJson(map));
  }

  void _applyNewComment(PostComment comment) {
    if (!mounted) return;
    setState(() {
      if (_post != null) _post!.commentCount++;
      if (comment.parentId == null) {
        _comments.insert(0, comment);
      } else {
        final idx = _comments.indexWhere((c) => c.id == comment.parentId);
        if (idx != -1) {
          final parent = _comments[idx];
          parent.replyCount++;
          if (_expandedIds.contains(parent.id) || parent.replies.length < 3) {
            parent.replies.add(comment);
          }
        }
      }
    });
  }

  Future<void> _viewMoreReplies(PostComment comment) async {
    if (_expandedIds.contains(comment.id) || _repliesLoading.contains(comment.id)) return;
    setState(() => _repliesLoading.add(comment.id));
    try {
      final data = await Api.instance
          .get('/posts/${widget.postId}/comments/${comment.id}/replies');
      final replies = (data is List ? data : const [])
          .whereType<Map>()
          .map((e) => PostComment.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      for (final r in replies) {
        _seenIds.add(r.id);
      }
      setState(() {
        comment.replies = replies;
        _expandedIds.add(comment.id);
        _repliesLoading.remove(comment.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _repliesLoading.remove(comment.id));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load replies: $e')));
    }
  }

  Future<void> _toggleCommentLike(PostComment comment) async {
    final wasLiked = comment.liked;
    setState(() {
      comment.liked = !wasLiked;
      comment.likeCount += wasLiked ? -1 : 1;
    });
    try {
      final res = await Api.instance
          .post('/posts/${widget.postId}/comments/${comment.id}/like');
      if (mounted && res is Map && res['liked'] is bool) {
        setState(() => comment.liked = res['liked'] as bool);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          comment.liked = wasLiked;
          comment.likeCount += wasLiked ? 1 : -1;
        });
      }
    }
  }

  Future<bool> _send(String body, PendingAttachment? attachment) async {
    try {
      final parentId = _replyTarget?.id;
      final res = await Api.instance.post('/posts/${widget.postId}/comments', body: {
        'body': body,
        'parentId': ?parentId,
        if (attachment != null) 'mediaUrl': attachment.url,
        if (attachment != null) 'mediaType': attachment.mediaType,
      });
      if (res is Map) {
        final created = PostComment.fromJson(res.cast<String, dynamic>());
        _seenIds.add(created.id);
        _applyNewComment(created);
      }
      if (mounted) setState(() => _replyTarget = null);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Comment failed: $e')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: _loading
          ? const CenterSpinner()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        color: KliqColors.cyan,
                        onRefresh: _load,
                        child: ListView(
                          children: [
                            PostCard(post: _post!, gradientSeed: 0),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(
                                  'Comments (${_post?.commentCount ?? _comments.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (_comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text('Be the first to comment',
                                      style: TextStyle(
                                          color: KliqColors.textMuted)),
                                ),
                              )
                            else
                              for (final c in _comments)
                                CommentTile(
                                  comment: c,
                                  onToggleLike: _toggleCommentLike,
                                  onReply: (target) =>
                                      setState(() => _replyTarget = target),
                                  onViewMoreReplies: _viewMoreReplies,
                                  repliesLoading:
                                      _repliesLoading.contains(c.id),
                                  expanded: _expandedIds.contains(c.id),
                                ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    CommentComposer(
                      onSubmit: _send,
                      replyingToUsername: _replyTarget?.author.username,
                      onCancelReply: () =>
                          setState(() => _replyTarget = null),
                      avatarUrl: session.user?['avatarUrl'] as String?,
                    ),
                  ],
                ),
    );
  }
}

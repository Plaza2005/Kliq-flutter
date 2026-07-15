import 'dart:async';

import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../discover/discover_common.dart' show CenterSpinner, ErrorState, KliqAvatar;
import '../home/feed_models.dart';

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

/// Kind of attachment a comment/reply can carry. Only [image] is wired up
/// this phase; the enum exists so a later phase can add "video"/"sticker"
/// to the same attach-button menu without reshaping the composer.
enum CommentAttachmentKind { image }

class PendingAttachment {
  const PendingAttachment(this.kind, this.url, this.mediaType);
  final CommentAttachmentKind kind;
  final String url;
  final String mediaType;
}

/// Opens the shared comments modal for [postId]. [initialCommentCount] seeds
/// the header count before the network call resolves; [onCommentCountChanged]
/// is invoked with the new total whenever a comment/reply is added (locally
/// or by another user in realtime) so the caller (post card / reel / detail
/// page) can keep its own badge in sync.
Future<void> showCommentsSheet(
  BuildContext context, {
  required String postId,
  int initialCommentCount = 0,
  ValueChanged<int>? onCommentCountChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(
      postId: postId,
      initialCommentCount: initialCommentCount,
      onCommentCountChanged: onCommentCountChanged,
    ),
  );
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.postId,
    this.initialCommentCount = 0,
    this.onCommentCountChanged,
  });

  final String postId;
  final int initialCommentCount;
  final ValueChanged<int>? onCommentCountChanged;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _comments = <PostComment>[];
  final _seenIds = <String>{};
  final _expandedIds = <String>{};
  final _repliesLoading = <String>{};
  PostComment? _replyTarget;
  bool _loading = true;
  String? _error;
  late int _commentCount;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.initialCommentCount;
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
      final data = await Api.instance.get('/posts/${widget.postId}/comments');
      final comments = (data is List ? data : const [])
          .whereType<Map>()
          .map((e) => PostComment.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      for (final c in comments) {
        _seenIds.add(c.id);
        for (final r in c.replies) {
          _seenIds.add(r.id);
        }
      }
      setState(() {
        _comments
          ..clear()
          ..addAll(comments);
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
    final comment = PostComment.fromJson(map);
    _applyNewComment(comment);
  }

  void _applyNewComment(PostComment comment) {
    if (!mounted) return;
    setState(() {
      _commentCount++;
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
    widget.onCommentCountChanged?.call(_commentCount);
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

  void _setReplyTarget(PostComment? c) => setState(() => _replyTarget = c);

  Future<bool> _submit(String body, PendingAttachment? attachment) async {
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: KliqColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: KliqColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Text('Comments (${formatCount(_commentCount)})',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                const Divider(height: 1),
                Expanded(child: _body(scrollController)),
                const Divider(height: 1),
                CommentComposer(
                  onSubmit: _submit,
                  replyingToUsername: _replyTarget?.author.username,
                  onCancelReply: () => _setReplyTarget(null),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(ScrollController scrollController) {
    if (_loading) return const CenterSpinner();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_comments.isEmpty) {
      return ListView(
        controller: scrollController,
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('Be the first to comment',
                  style: TextStyle(color: KliqColors.textMuted)),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _comments.length,
      itemBuilder: (context, i) {
        final c = _comments[i];
        return CommentTile(
          comment: c,
          onToggleLike: _toggleCommentLike,
          onReply: _setReplyTarget,
          onViewMoreReplies: _viewMoreReplies,
          repliesLoading: _repliesLoading.contains(c.id),
          expanded: _expandedIds.contains(c.id),
        );
      },
    );
  }
}

/// Shared comment (+ preview replies) renderer — used by the modal sheet
/// above and by [PostDetailPage]'s full-page thread so there is one
/// implementation of comment-tile rendering.
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.onToggleLike,
    required this.onReply,
    this.onViewMoreReplies,
    this.repliesLoading = false,
    this.expanded = false,
    this.isReply = false,
  });

  final PostComment comment;
  final ValueChanged<PostComment> onToggleLike;
  final ValueChanged<PostComment> onReply;
  final ValueChanged<PostComment>? onViewMoreReplies;
  final bool repliesLoading;
  final bool expanded;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final hiddenCount = comment.replyCount - comment.replies.length;
    final hasMoreHidden = !isReply && !expanded && hiddenCount > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(isReply ? 40 : 14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KliqAvatar(comment.author.avatarUrl, radius: isReply ? 13 : 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(comment.author.username,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo(comment.createdAt),
                        style: const TextStyle(
                            color: KliqColors.textMuted, fontSize: 11)),
                  ],
                ),
                if (comment.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(comment.body),
                ],
                if (comment.mediaUrl != null && comment.mediaUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        Api.instance.mediaUrl(comment.mediaUrl!),
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 140,
                          height: 140,
                          color: KliqColors.surfaceElevated,
                          child: const Icon(Icons.broken_image_outlined,
                              color: KliqColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (comment.likeCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Text('${formatCount(comment.likeCount)} likes',
                              style: const TextStyle(
                                  color: KliqColors.textMuted, fontSize: 11)),
                        ),
                      GestureDetector(
                        onTap: () => onReply(comment),
                        child: const Text('Reply',
                            style: TextStyle(
                                color: KliqColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                if (!isReply && comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final r in comment.replies)
                    CommentTile(
                      comment: r,
                      onToggleLike: onToggleLike,
                      onReply: onReply,
                      isReply: true,
                    ),
                ],
                if (hasMoreHidden)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      onTap: repliesLoading
                          ? null
                          : () => onViewMoreReplies?.call(comment),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 24, height: 1, color: KliqColors.border),
                          const SizedBox(width: 8),
                          if (repliesLoading)
                            const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            Text(
                                'View $hiddenCount more ${hiddenCount == 1 ? 'reply' : 'replies'}',
                                style: const TextStyle(
                                    color: KliqColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onToggleLike(comment),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Icon(
                comment.liked ? Icons.favorite : Icons.favorite_border,
                size: 14,
                color: comment.liked ? KliqColors.pink : KliqColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared composer bar: text input + image-attach button + send. Used by
/// both the modal sheet and the full-page detail view.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.onSubmit,
    this.replyingToUsername,
    this.onCancelReply,
    this.avatarUrl,
  });

  /// Returns true on success (the composer clears itself); false leaves the
  /// text/attachment in place so the user can retry.
  final Future<bool> Function(String body, PendingAttachment? attachment) onSubmit;
  final String? replyingToUsername;
  final VoidCallback? onCancelReply;
  final String? avatarUrl;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  PendingAttachment? _attachment;
  bool _uploading = false;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (picked == null) return;
      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final res = await Api.instance
          .upload('/upload', MultipartFile.fromBytes(bytes, filename: picked.name));
      final url = res is Map ? res['url']?.toString() : null;
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        setState(() =>
            _attachment = PendingAttachment(CommentAttachmentKind.image, url, 'image'));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty && _attachment == null) return;
    if (_sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSubmit(body, _attachment);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _controller.clear();
        _attachment = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.replyingToUsername != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Replying to @${widget.replyingToUsername}',
                        style: const TextStyle(
                            color: KliqColors.textSecondary, fontSize: 12)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onCancelReply,
                      child: const Icon(Icons.close,
                          size: 14, color: KliqColors.textMuted),
                    ),
                  ],
                ),
              ),
            if (_attachment != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 40),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        Api.instance.mediaUrl(_attachment!.url),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: GestureDetector(
                        onTap: () => setState(() => _attachment = null),
                        child: const CircleAvatar(
                          radius: 9,
                          backgroundColor: KliqColors.danger,
                          child: Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                KliqAvatar(widget.avatarUrl, radius: 15),
                const SizedBox(width: 6),
                IconButton(
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image_outlined,
                          color: KliqColors.textSecondary),
                  onPressed: _uploading ? null : _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: widget.replyingToUsername != null
                          ? 'Reply…'
                          : 'Add a comment…',
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: KliqColors.cyan),
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

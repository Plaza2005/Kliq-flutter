import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../common/comments_sheet.dart';
import '../../common/kliq_video.dart';
import '../../common/share_sheet.dart';
import '../feed_models.dart';
import 'caption_text.dart';
import 'kliq_avatar.dart';

const _textCardGradients = [
  [Color(0xFF4C1D95), Color(0xFF1E1B4B), Colors.black],
  [Color(0xFF831843), Color(0xFF881337), Colors.black],
  [Color(0xFF312E81), Color(0xFF1E3A8A), Colors.black],
  [Color(0xFF064E3B), Color(0xFF134E4A), Colors.black],
  [Color(0xFF7C2D12), Color(0xFF7F1D1D), Colors.black],
];

/// Instagram-style feed post card: header, media/carousel or text body,
/// action row (like/comment/share/save), caption and timestamp.
class PostCard extends StatefulWidget {
  const PostCard(
      {super.key, required this.post, this.gradientSeed = 0, this.onChanged});

  final Post post;
  final int gradientSeed;

  /// Called after the viewer edits or deletes their own post, so the host
  /// (feed/profile) can refresh.
  final VoidCallback? onChanged;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _mediaIndex = 0;
  bool _showHeart = false;
  bool _likeBusy = false;
  bool _repostBusy = false;

  Post get post => widget.post;

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    _likeBusy = true;
    final wasLiked = post.liked;
    setState(() {
      post.liked = !wasLiked;
      post.likeCount += wasLiked ? -1 : 1;
    });
    try {
      final res = wasLiked
          ? await Api.instance.delete('/posts/${post.id}/like')
          : await Api.instance.post('/posts/${post.id}/like');
      if (res is Map && res['likeCount'] is int && mounted) {
        setState(() => post.likeCount = res['likeCount'] as int);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          post.liked = wasLiked;
          post.likeCount += wasLiked ? 1 : -1;
        });
      }
    } finally {
      _likeBusy = false;
    }
  }

  Future<void> _toggleRepost() async {
    if (_repostBusy) return;
    _repostBusy = true;
    final wasReposted = post.reposted;
    setState(() {
      post.reposted = !wasReposted;
      post.repostCount += wasReposted ? -1 : 1;
    });
    try {
      final res = await Api.instance.post('/posts/${post.id}/repost');
      if (res is Map && res['reposted'] is bool && mounted) {
        setState(() => post.reposted = res['reposted'] as bool);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          post.reposted = wasReposted;
          post.repostCount += wasReposted ? 1 : -1;
        });
      }
    } finally {
      _repostBusy = false;
    }
  }

  Future<void> _toggleSave() async {
    final wasSaved = post.saved;
    setState(() => post.saved = !wasSaved);
    try {
      if (wasSaved) {
        await Api.instance.delete('/bookmarks/${post.id}');
      } else {
        await Api.instance.post('/bookmarks/${post.id}');
      }
    } catch (_) {
      if (mounted) setState(() => post.saved = wasSaved);
    }
  }

  void _doubleTapLike() {
    if (!post.liked) _toggleLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _share() {
    showShareSheet(
      context,
      target: ShareTarget(
        postId: post.id,
        authorUsername: post.author.username,
        caption: post.body,
        mediaUrl: post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null,
        mediaType: post.isVideo ? 'video' : 'image',
      ),
      onShared: () {
        if (mounted) setState(() => post.shareCount += 1);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.repostedBy != null) _repostBanner(context),
        _header(context),
        _media(context),
        _actions(context),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.likeCount > 0)
                Text('${formatCount(post.likeCount)} likes',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              if (post.body.isNotEmpty && !post.isText) ...[
                const SizedBox(height: 4),
                CaptionText(
                  text: post.body,
                  leadingUsername: post.author.username,
                  maxLines: 3,
                ),
              ],
              if (post.commentCount > 0) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.push('/post/${post.id}'),
                  child: Text(
                    'View all ${formatCount(post.commentCount)} comments',
                    style: const TextStyle(
                        color: KliqColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(timeAgo(post.createdAt),
                  style: const TextStyle(
                      color: KliqColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _repostBanner(BuildContext context) {
    final by = post.repostedBy!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GestureDetector(
        onTap: () => context.push('/user/${by.username}'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.repeat, size: 15, color: KliqColors.textSecondary),
            const SizedBox(width: 6),
            Text('Reposted by @${by.username}',
                style: const TextStyle(
                    color: KliqColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          KliqAvatar(
            url: post.author.avatarUrl,
            size: 36,
            onTap: () => context.push('/user/${post.author.username}'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/user/${post.author.username}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(post.author.username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13.5)),
                      ),
                      if (post.author.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 13, color: KliqColors.cyan),
                      ],
                    ],
                  ),
                  if (post.location != null && post.location!.isNotEmpty)
                    Text(post.location!,
                        style: const TextStyle(
                            color: KliqColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 20),
            onPressed: () => _showMoreSheet(context),
          ),
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: KliqColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  post.saved ? Icons.bookmark : Icons.bookmark_border,
                  color: KliqColors.textPrimary),
              title: Text(post.saved ? 'Unsave' : 'Save'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _toggleSave();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.share_outlined, color: KliqColors.textPrimary),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _share();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline,
                  color: KliqColors.textPrimary),
              title: Text('View @${post.author.username}'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push('/user/${post.author.username}');
              },
            ),
            if (_isOwnPost(context)) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: KliqColors.textPrimary),
                title: const Text('Edit caption'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _editPost(context);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: KliqColors.danger),
                title: const Text('Delete post',
                    style: TextStyle(color: KliqColors.danger)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _deletePost(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isOwnPost(BuildContext context) =>
      context.read<Session>().username == post.author.username;

  Future<void> _editPost(BuildContext context) async {
    final controller = TextEditingController(text: post.body);
    final messenger = ScaffoldMessenger.of(context);
    final newBody = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KliqColors.surfaceElevated,
        title: const Text('Edit caption'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(hintText: 'Write a caption…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newBody == null) return;
    try {
      await Api.instance.patch('/posts/${post.id}', body: {'body': newBody});
      messenger.showSnackBar(const SnackBar(content: Text('Post updated')));
      widget.onChanged?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KliqColors.surfaceElevated,
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: KliqColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Api.instance.delete('/posts/${post.id}');
      messenger.showSnackBar(const SnackBar(content: Text('Post deleted')));
      widget.onChanged?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  Widget _media(BuildContext context) {
    if (post.isText) {
      final colors =
          _textCardGradients[widget.gradientSeed % _textCardGradients.length];
      return GestureDetector(
        onDoubleTap: _doubleTapLike,
        onTap: () => context.push('/post/${post.id}'),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 220),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: CaptionText(
                text: post.body,
                maxLines: 8,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    height: 1.45),
              ),
            ),
            _heartOverlay(),
          ],
        ),
      );
    }

    if (post.isVideo && post.mediaUrls.isNotEmpty) {
      return GestureDetector(
        onDoubleTap: _doubleTapLike,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: KliqVideo(
                url: post.mediaUrls.first,
                controlsEnabled: false,
                loop: true,
                autoPlay: true,
                muted: true,
                fit: BoxFit.cover,
              ),
            ),
            _heartOverlay(),
          ],
        ),
      );
    }

    final many = post.mediaUrls.length > 1;
    return GestureDetector(
      onDoubleTap: _doubleTapLike,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: many
                ? PageView.builder(
                    itemCount: post.mediaUrls.length,
                    onPageChanged: (i) => setState(() => _mediaIndex = i),
                    itemBuilder: (c, i) => _image(post.mediaUrls[i]),
                  )
                : _image(post.mediaUrls.first),
          ),
          if (many)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_mediaIndex + 1}/${post.mediaUrls.length}',
                    style: const TextStyle(fontSize: 11)),
              ),
            ),
          if (many)
            Positioned(
              bottom: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < post.mediaUrls.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _mediaIndex
                            ? KliqColors.cyan
                            : Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
          _heartOverlay(),
        ],
      ),
    );
  }

  Widget _heartOverlay() {
    return AnimatedOpacity(
      opacity: _showHeart ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: _showHeart ? 1 : 0.4,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.favorite, size: 96, color: Colors.white70),
      ),
    );
  }

  Widget _image(String url) {
    return CachedNetworkImage(
      imageUrl: Api.instance.mediaUrl(url),
      fit: BoxFit.cover,
      placeholder: (c, s) => Container(color: KliqColors.surface),
      errorWidget: (c, s, e) => Container(
        color: KliqColors.surface,
        child: const Icon(Icons.broken_image_outlined,
            color: KliqColors.textMuted, size: 40),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              post.liked ? Icons.favorite : Icons.favorite_border,
              color: post.liked ? KliqColors.pink : KliqColors.textPrimary,
            ),
            onPressed: _toggleLike,
          ),
          IconButton(
            icon: const Icon(Icons.mode_comment_outlined),
            onPressed: () => showCommentsSheet(
              context,
              postId: post.id,
              initialCommentCount: post.commentCount,
              onCommentCountChanged: (n) {
                if (mounted) setState(() => post.commentCount = n);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            onPressed: _share,
          ),
          if (post.shareCount > 0)
            Text(formatCount(post.shareCount),
                style: const TextStyle(
                    color: KliqColors.textSecondary, fontSize: 12)),
          IconButton(
            icon: Icon(
              Icons.repeat,
              color: post.reposted ? KliqColors.cyan : KliqColors.textPrimary,
            ),
            onPressed: _toggleRepost,
          ),
          if (post.repostCount > 0)
            Text(formatCount(post.repostCount),
                style: const TextStyle(
                    color: KliqColors.textSecondary, fontSize: 12)),
          const Spacer(),
          IconButton(
            icon: Icon(
              post.saved ? Icons.bookmark : Icons.bookmark_border,
              color: post.saved ? KliqColors.cyan : KliqColors.textPrimary,
            ),
            onPressed: _toggleSave,
          ),
        ],
      ),
    );
  }
}

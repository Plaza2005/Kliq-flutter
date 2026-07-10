import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart' show CenterSpinner, ErrorState, KliqAvatar;
import 'feed_models.dart';
import 'widgets/post_card.dart';

/// Post page: the full post card plus its comment thread and a composer.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Post? _post;
  List<PostComment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  final _composer = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
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
      setState(() {
        _post = Post.fromJson(
            (post as Map).cast<String, dynamic>());
        _comments = (comments is List ? comments : const [])
            .whereType<Map>()
            .map((e) => PostComment.fromJson(e.cast<String, dynamic>()))
            .toList();
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

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.instance
          .post('/posts/${widget.postId}/comments', body: {'body': body});
      _composer.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Comment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
                                  'Comments (${_comments.length})',
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
                              for (final c in _comments) _CommentTile(c),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            KliqAvatar(
                                session.user?['avatarUrl'] as String?,
                                radius: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _composer,
                                decoration: const InputDecoration(
                                    hintText: 'Add a comment…'),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            IconButton(
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.send,
                                      color: KliqColors.cyan),
                              onPressed: _send,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile(this.comment);

  final PostComment comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KliqAvatar(comment.author.avatarUrl, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.author.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(timeAgo(comment.createdAt),
                        style: const TextStyle(
                            color: KliqColors.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body),
                if (comment.likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${formatCount(comment.likeCount)} likes',
                        style: const TextStyle(
                            color: KliqColors.textMuted, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

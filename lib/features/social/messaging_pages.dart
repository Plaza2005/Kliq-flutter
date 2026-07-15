import 'dart:async';

import 'package:dio/dio.dart' show MultipartFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../common/kliq_composer.dart';
import '../common/people_picker_sheet.dart';
import '../common/sticker_library.dart' show saveMediaToStickerLibrary;
import '../discover/discover_common.dart';

/// Short "replying to" preview text mirroring the server's own snippet
/// convention (see messages.ts/groups.ts `replySnippet`): truncated body,
/// or a placeholder for media/deleted messages.
String _snippetForMessage(Map<String, dynamic> m) {
  final mediaType = pickStr(m, ['mediaType']);
  final mediaUrl = pickStr(m, ['mediaUrl']);
  if (m['deleted'] == true) return 'Message deleted';
  if (mediaType == 'sticker') return 'Sticker';
  if (mediaType == 'audio') return 'Voice message';
  if (mediaType == 'image' || mediaUrl.isNotEmpty) return 'Photo';
  final trimmed = pickStr(m, ['body']).trim();
  if (trimmed.isEmpty) return '';
  return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
}

const _quickReactions = ['❤️', '😂', '😮', '👍', '😢', '🔥'];

/// Returns the first thread map matching [test], or null if none match.
Map<String, dynamic>? _findThread(
  List<Map<String, dynamic>> threads,
  bool Function(Map<String, dynamic>) test,
) {
  for (final t in threads) {
    if (test(t)) return t;
  }
  return null;
}

/// Direct messaging: inbox of DM threads + group chats, and a 1:1/group chat
/// screen. Wired to the real API — GET /messages/threads, GET /groups,
/// GET/POST /messages/threads/:id, GET/POST /groups/:id/messages,
/// POST /messages/send.

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads DM threads and group chats and merges them into one
  /// recency-sorted inbox list.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.instance.get('/messages/threads').catchError((_) => []),
        Api.instance.get('/groups').catchError((_) => []),
      ]);

      final threads = asMapList(results[0]).map((t) {
        final other = asMap(t['other']);
        final last = asMap(t['lastMessage']);
        return <String, dynamic>{
          'kind': 'thread',
          'id': t['threadId'],
          'title': pickStr(other, ['displayName', 'username'], fallback: 'Chat'),
          'avatarUrl': other['avatarUrl'],
          'preview': pickStr(last, ['body']),
          'sortAt': t['updatedAt']?.toString() ?? '',
        };
      });

      final groups = asMapList(results[1]).map((g) {
        final msgs = asMapList(g['messages']);
        final last = msgs.isNotEmpty ? msgs.first : <String, dynamic>{};
        final lastAt = pickStr(last, ['createdAt']);
        return <String, dynamic>{
          'kind': 'group',
          'id': g['id'],
          'title': pickStr(g, ['name'], fallback: 'Group chat'),
          'avatarUrl': g['avatarUrl'],
          'preview': pickStr(last, ['body']),
          'sortAt': lastAt.isNotEmpty ? lastAt : (g['createdAt']?.toString() ?? ''),
        };
      });

      final merged = [...threads, ...groups];
      merged.sort((a, b) {
        final da = DateTime.tryParse(a['sortAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['sortAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      if (mounted) {
        setState(() {
          _conversations = merged;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens the shared multi-select people picker. Exactly one person picked
  /// -> normal 1:1 chat; more than one -> create a group; "Create a
  /// community" -> create a community and open its chat.
  Future<void> _startChat() async {
    final result = await showPeoplePickerSheet(context,
        title: 'New message', confirmLabel: 'Chat');
    if (result == null || !mounted) return;

    if (result.createCommunity) {
      await _createCommunity();
    } else if (result.users.length == 1) {
      final userId = result.users.first['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await context.push('/chat/$userId');
        _load();
      }
    } else if (result.users.length > 1) {
      await _createGroup(result.users);
    }
  }

  Future<void> _createGroup(List<Map<String, dynamic>> users) async {
    final defaultName =
        users.map((u) => pickStr(u, ['displayName', 'username'])).join(', ');
    final name = await _promptName(
      title: 'Name this group',
      initial: defaultName,
    );
    if (name == null || !mounted) return;
    try {
      final memberUsernames = users
          .map((u) => u['username']?.toString())
          .whereType<String>()
          .toList();
      final group = await Api.instance.post('/groups', body: {
        'name': name,
        'memberUsernames': memberUsernames,
      });
      if (!mounted) return;
      final id = asMap(group)['id']?.toString();
      if (id != null) {
        await context.push('/group/$id');
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not create group: $e')));
      }
    }
  }

  Future<void> _createCommunity() async {
    final name = await _promptName(title: 'Name your community');
    if (name == null || !mounted) return;
    try {
      final community =
          await Api.instance.post('/communities', body: {'name': name});
      if (!mounted) return;
      final id = asMap(community)['id']?.toString();
      if (id != null) {
        await context.push('/community/$id');
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create community: $e')));
      }
    }
  }

  Future<String?> _promptName({required String title, String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KliqColors.surfaceElevated,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = controller.text.trim();
              Navigator.of(ctx).pop(v.isEmpty ? null : v);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Inbox', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Start a chat',
            icon: const Icon(Icons.edit_square),
            onPressed: _startChat,
          ),
        ],
      ),
      body: _loading
          ? const CenterSpinner()
          : _conversations.isEmpty
              ? const EmptyState(
                  icon: Icons.send_outlined,
                  title: 'No messages yet',
                  subtitle: 'Start a chat from any profile')
              : RefreshIndicator(
                  color: KliqColors.cyan,
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, i) {
                      final c = _conversations[i];
                      final isGroup = c['kind'] == 'group';
                      return ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            KliqAvatar(c['avatarUrl']?.toString(), radius: 22),
                            if (isGroup)
                              const Positioned(
                                right: -2,
                                bottom: -2,
                                child: CircleAvatar(
                                  radius: 8,
                                  backgroundColor: KliqColors.purple,
                                  child: Icon(Icons.group,
                                      size: 10, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        title: Text(pickStr(c, ['title'], fallback: 'Chat'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            pickStr(c, ['preview'],
                                fallback: isGroup
                                    ? 'No messages yet'
                                    : 'Say hello'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: KliqColors.textMuted, fontSize: 12.5)),
                        trailing: Text(
                            timeAgo(c['sortAt']?.toString()),
                            style: const TextStyle(
                                color: KliqColors.textMuted, fontSize: 11)),
                        onTap: () {
                          if (isGroup) {
                            context.push('/group/${c['id']}');
                          } else {
                            context.push('/chat/${c['id']}?type=thread');
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    this.isGroup = false,
    this.isThreadId = false,
  });

  /// For 1:1 chats this is either a userId (isThreadId=false — resolve or
  /// lazily create the DM thread, e.g. when opened from a profile) or an
  /// existing threadId (isThreadId=true — opened from the inbox list). For
  /// group chats (isGroup=true) this is always the groupId.
  final String conversationId;
  final bool isGroup;
  final bool isThreadId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _other = {};
  String? _threadId;
  bool _loading = true;
  StreamSubscription? _wsSub;

  /// Set while composing a reply — shows the quote bar above [KliqComposer]
  /// and is sent as `replyToId` on the next message.
  Map<String, dynamic>? _replyingTo;

  @override
  void initState() {
    super.initState();
    _threadId = widget.isThreadId ? widget.conversationId : null;
    _load();
    _wsSub = WsService.instance.events.listen(_onWsEvent);
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }

  void _onWsEvent(Map<String, dynamic> e) {
    if (widget.isGroup) {
      if (e['type'] == 'group:message' &&
          e['groupId']?.toString() == widget.conversationId) {
        final msg = asMap(e['message']);
        if (mounted) setState(() => _messages.add(msg));
      }
      return;
    }
    if (_threadId == null || e['threadId']?.toString() != _threadId) return;
    switch (e['type']) {
      case 'message:new':
        final copy = Map<String, dynamic>.from(e)..remove('type');
        if (mounted) setState(() => _messages.add(copy));
        break;
      case 'message:deleted':
        final id = e['messageId']?.toString();
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((x) => x['id']?.toString() == id);
            if (idx != -1) {
              _messages[idx] = {
                ..._messages[idx],
                'deleted': true,
                'body': '',
                'mediaUrl': null,
                'mediaType': null,
              };
            }
          });
        }
        break;
      case 'message:reaction':
        final id = e['messageId']?.toString();
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((x) => x['id']?.toString() == id);
            if (idx != -1) {
              final upd = Map<String, dynamic>.from(_messages[idx]);
              upd['reactions'] = asMap(e['reactions']);
              if (e['myReaction'] != null) upd['myReaction'] = e['myReaction'];
              _messages[idx] = upd;
            }
          });
        }
        break;
    }
  }

  Future<void> _load() async {
    try {
      if (widget.isGroup) {
        final info =
            await Api.instance.get('/groups/${widget.conversationId}');
        final infoMap = asMap(info);
        _other = {
          'displayName': pickStr(infoMap, ['name'], fallback: 'Group chat'),
          'avatarUrl': infoMap['avatarUrl'],
        };
        final data =
            await Api.instance.get('/groups/${widget.conversationId}/messages');
        // Server returns newest-first; the message list below is oldest-first.
        _messages = asMapList(data).reversed.toList();
      } else {
        final threads =
            await Api.instance.get('/messages/threads').catchError((_) => []);
        final threadList = asMapList(threads);
        final matched = _findThread(
          threadList,
          widget.isThreadId
              ? (t) => t['threadId']?.toString() == widget.conversationId
              : (t) =>
                  asMap(t['other'])['id']?.toString() == widget.conversationId,
        );
        if (!widget.isThreadId) {
          _threadId = matched?['threadId']?.toString();
        }
        if (matched != null) {
          _other = asMap(matched['other']);
        } else if (!widget.isThreadId) {
          // No thread yet — fetch the recipient's profile for the header.
          final u = await Api.instance
              .get('/users/${widget.conversationId}')
              .catchError((_) => null);
          if (u != null) _other = asMap(u);
        }
        if (_threadId != null) {
          final data =
              await Api.instance.get('/messages/threads/$_threadId');
          _messages = asMapList(data);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sends a message with any combination of [body] text and a media
  /// attachment ([mediaUrl] + [mediaType]) — used for plain text sends, for
  /// stickers picked from the composer (mediaType 'sticker'), and for
  /// image attachments (mediaType 'image'). Optimistically appends the
  /// message locally, then posts to whichever send path applies (DM
  /// `/messages/send` or group `/groups/:id/messages`).
  Future<void> _sendMessage({String? body, String? mediaUrl, String? mediaType}) async {
    final text = body?.trim() ?? '';
    if (text.isEmpty && mediaUrl == null) return;
    final replyToId = _replyingTo?['id']?.toString();
    final replyToSnapshot = _replyingTo;
    final myId = context.read<Session>().userId;
    setState(() {
      _messages.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'senderId': myId,
        'body': text,
        'mediaUrl': ?mediaUrl,
        'mediaType': ?mediaType,
        'createdAt': DateTime.now().toIso8601String(),
        'isMine': true,
        if (replyToSnapshot != null)
          'replyTo': {
            'id': replyToSnapshot['id'],
            'senderUsername': replyToSnapshot['senderName'],
            'snippet': replyToSnapshot['snippet'],
          },
      });
      _replyingTo = null;
    });

    try {
      if (widget.isGroup) {
        await Api.instance.post('/groups/${widget.conversationId}/messages', body: {
          'body': text,
          'mediaUrl': ?mediaUrl,
          'mediaType': ?mediaType,
          'replyToId': ?replyToId,
        });
      } else {
        final res = await Api.instance.post('/messages/send', body: {
          if (_threadId != null)
            'threadId': _threadId
          else
            'recipientId': widget.conversationId,
          'body': text,
          'mediaUrl': ?mediaUrl,
          'mediaType': ?mediaType,
          'replyToId': ?replyToId,
        });
        final threadId = asMap(res)['threadId']?.toString();
        if (threadId != null) _threadId = threadId;
      }
    } catch (_) {}
  }

  /// Sets the "replying to" quote bar shown above the composer; [message]
  /// is the tapped/long-pressed/swiped bubble's data.
  void _startReply(Map<String, dynamic> message) {
    final myId = context.read<Session>().userId;
    final sender = asMap(message['sender']);
    final senderId = pickStr(message, ['senderId']);
    final senderName = sender.isNotEmpty
        ? pickStr(sender, ['displayName', 'username'], fallback: 'User')
        : (senderId == myId
            ? 'You'
            : pickStr(_other, ['displayName', 'username'], fallback: 'User'));
    setState(() {
      _replyingTo = {
        'id': message['id']?.toString(),
        'senderName': senderName,
        'snippet': _snippetForMessage(message),
      };
    });
  }

  Future<void> _copyMessage(Map<String, dynamic> m) async {
    final body = pickStr(m, ['body']);
    if (body.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: body));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Copied')));
    }
  }

  /// Reuses the existing DM reaction endpoint (`POST /messages/:id/react`).
  /// No equivalent endpoint exists for group messages yet, so reactions are
  /// DM-only for now.
  Future<void> _reactToMessage(Map<String, dynamic> m, String emoji) async {
    if (widget.isGroup) return;
    final id = pickStr(m, ['id']);
    if (id.isEmpty) return;
    try {
      final res = await Api.instance.post('/messages/$id/react', body: {'emoji': emoji});
      final data = asMap(res);
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((x) => x['id']?.toString() == id);
          if (idx != -1) {
            _messages[idx] = {
              ..._messages[idx],
              'reactions': asMap(data['reactions']),
              'myReaction': data['myReaction'],
            };
          }
        });
      }
    } catch (_) {}
  }

  /// Reuses the existing DM soft-delete endpoint (`DELETE /messages/:id`),
  /// which already pushes `message:deleted` over WS to the other party.
  /// No equivalent endpoint exists for group messages yet.
  Future<void> _deleteMessage(Map<String, dynamic> m) async {
    if (widget.isGroup) return;
    final id = pickStr(m, ['id']);
    if (id.isEmpty) return;
    try {
      await Api.instance.delete('/messages/$id');
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((x) => x['id']?.toString() == id);
          if (idx != -1) {
            _messages[idx] = {
              ..._messages[idx],
              'deleted': true,
              'body': '',
              'mediaUrl': null,
              'mediaType': null,
            };
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  /// Long-press context menu: Reply / Copy / React (DM only) / Delete (own
  /// DM messages only — no group delete endpoint exists yet).
  Future<void> _showMessageMenu(Map<String, dynamic> m, bool mine) async {
    final canCopy = pickStr(m, ['body']).isNotEmpty && m['deleted'] != true;
    final canReact = !widget.isGroup && m['deleted'] != true;
    final canDelete = mine && !widget.isGroup && m['deleted'] != true;
    await showModalBottomSheet(
      context: context,
      backgroundColor: KliqColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReact)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Wrap(
                  spacing: 16,
                  children: _quickReactions
                      .map((emoji) => GestureDetector(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _reactToMessage(m, emoji);
                            },
                            child: Text(emoji, style: const TextStyle(fontSize: 26)),
                          ))
                      .toList(),
                ),
              ),
            if (canReact) const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(ctx).pop();
                _startReply(m);
              },
            ),
            if (canCopy)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _copyMessage(m);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteMessage(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Uploads a finished voice recording (from [KliqComposer.onVoiceMessage])
  /// through the existing `/upload` endpoint (already whitelists `.m4a`)
  /// and sends it as an `audio` message.
  Future<void> _sendVoiceMessage(String localPath) async {
    try {
      final bytes = await XFile(localPath).readAsBytes();
      final res = await Api.instance.upload(
        '/upload',
        MultipartFile.fromBytes(bytes,
            filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a'),
      );
      final url = res is Map ? res['url']?.toString() : null;
      if (url != null && url.isNotEmpty) {
        await _sendMessage(mediaUrl: url, mediaType: 'audio');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Voice message failed: $e')));
      }
    }
  }

  /// Attach-image handler for the composer's generic attach button: picks
  /// from the gallery, uploads it, then sends it as its own image message.
  Future<void> _attachImage() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final res = await Api.instance
          .upload('/upload', MultipartFile.fromBytes(bytes, filename: picked.name));
      final url = res is Map ? res['url']?.toString() : null;
      if (url != null && url.isNotEmpty) {
        await _sendMessage(mediaUrl: url, mediaType: 'image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  /// Small quoted-preview strip shown above a message's own content when it
  /// carries a `replyTo` (sender + truncated snippet, from the server for
  /// loaded messages or synthesized locally for an optimistic send).
  Widget _replyPreview(Map<String, dynamic> m, bool mine) {
    final replyTo = asMap(m['replyTo']);
    if (replyTo.isEmpty) return const SizedBox.shrink();
    final barColor = mine ? Colors.white : KliqColors.cyan;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (mine ? Colors.white : KliqColors.cyan).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: barColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pickStr(replyTo, ['senderUsername'], fallback: 'User'),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: barColor),
          ),
          Text(
            pickStr(replyTo, ['snippet'], fallback: ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                color: mine ? Colors.white70 : KliqColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Emoji-count row rendered below a message's content when it has
  /// reactions (from `POST /messages/:id/react`'s broadcast reaction map).
  Widget _reactionsRow(Map<String, dynamic> m) {
    final reactions = asMap(m['reactions']);
    if (reactions.isEmpty) return const SizedBox.shrink();
    final text = reactions.entries
        .map((e) => e.value is num && (e.value as num) > 1
            ? '${e.key}${e.value}'
            : e.key)
        .join(' ');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  /// Renders a message bubble's content: an optional reply-quote strip, any
  /// media attachment (long-press to save a sticker into the user's
  /// library, mirroring comments_sheet.dart's `CommentTile`; an audio
  /// message renders as a playback bubble instead), the text body if any,
  /// and a reaction row if the message has reactions.
  Widget _bubbleContent(Map<String, dynamic> m, {required bool mine}) {
    final mediaUrl = pickStr(m, ['mediaUrl']);
    final mediaType = pickStr(m, ['mediaType']);
    final body = pickStr(m, ['body']);
    final isSticker = mediaType == 'sticker';
    final isAudio = mediaType == 'audio';
    final children = <Widget>[_replyPreview(m, mine)];
    if (isAudio && mediaUrl.isNotEmpty) {
      children.add(_AudioBubble(url: Api.instance.mediaUrl(mediaUrl), mine: mine));
    } else if (mediaUrl.isNotEmpty) {
      Widget image = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          Api.instance.mediaUrl(mediaUrl),
          width: isSticker ? 100 : 160,
          height: isSticker ? 100 : 160,
          fit: isSticker ? BoxFit.contain : BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
            width: isSticker ? 100 : 160,
            height: isSticker ? 100 : 160,
            color: KliqColors.surfaceElevated,
            child: const Icon(Icons.broken_image_outlined,
                color: KliqColors.textMuted),
          ),
        ),
      );
      if (isSticker) {
        image = GestureDetector(
          onLongPress: () =>
              saveMediaToStickerLibrary(context, mediaUrl, sourceType: 'chat'),
          child: image,
        );
      }
      children.add(image);
    }
    if (body.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 6));
      children.add(Text(body, style: const TextStyle(fontSize: 14)));
    }
    children.add(_reactionsRow(m));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<Session>().userId;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            KliqAvatar(_other['avatarUrl']?.toString(), radius: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pickStr(_other, ['displayName', 'username'],
                    fallback: widget.isGroup ? 'Group chat' : 'Chat'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const CenterSpinner()
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[_messages.length - 1 - i];
                      final mine =
                          pickStr(m, ['senderId']) == myId ||
                              asMap(m['sender'])['id'] == myId;
                      return _SwipeableBubble(
                        onReply: () => _startReply(m),
                        onLongPress: () => _showMessageMenu(m, mine),
                        child: Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width *
                                        0.72),
                            decoration: BoxDecoration(
                              gradient:
                                  mine ? KliqColors.gradient : null,
                              color: mine
                                  ? null
                                  : KliqColors.surfaceElevated,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft:
                                    Radius.circular(mine ? 16 : 4),
                                bottomRight:
                                    Radius.circular(mine ? 4 : 16),
                              ),
                            ),
                            child: _bubbleContent(m, mine: mine),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_replyingTo != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: KliqColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                    left: BorderSide(color: KliqColors.cyan, width: 3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Replying to ${_replyingTo!['senderName']}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: KliqColors.cyan),
                        ),
                        Text(
                          _replyingTo!['snippet']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: KliqColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: KliqColors.textMuted),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: KliqComposer(
                hintText: 'Message…',
                onSend: (text) => _sendMessage(body: text),
                onStickerSelected: (url) =>
                    _sendMessage(mediaUrl: url, mediaType: 'sticker'),
                onAttach: _attachImage,
                onVoiceMessage: _sendVoiceMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a message bubble with long-press (context menu) and
/// swipe-right-to-reply gestures. Dragging right past [_replyThreshold]
/// triggers [onReply] (same action as the long-press menu's Reply item);
/// the bubble slides with the drag and snaps back on release — a plain
/// `GestureDetector` + `AnimatedContainer` offset, no custom animation
/// controller needed for this simple a gesture.
class _SwipeableBubble extends StatefulWidget {
  const _SwipeableBubble({
    required this.child,
    required this.onReply,
    required this.onLongPress,
  });

  final Widget child;
  final VoidCallback onReply;
  final VoidCallback onLongPress;

  @override
  State<_SwipeableBubble> createState() => _SwipeableBubbleState();
}

class _SwipeableBubbleState extends State<_SwipeableBubble> {
  static const _replyThreshold = 56.0;
  static const _maxDrag = 80.0;

  double _dragDx = 0;
  bool _triggered = false;

  void _onDragUpdate(DragUpdateDetails d) {
    final next = (_dragDx + d.delta.dx).clamp(0.0, _maxDrag);
    setState(() => _dragDx = next);
    if (!_triggered && _dragDx >= _replyThreshold) {
      _triggered = true;
      widget.onReply();
    }
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _dragDx = 0);
    _triggered = false;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: () => setState(() => _dragDx = 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          if (_dragDx > 4)
            Opacity(
              opacity: (_dragDx / _replyThreshold).clamp(0, 1),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.reply, color: KliqColors.textMuted, size: 20),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.translationValues(_dragDx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Playback bubble for an `audio`-type message: a play/pause button and the
/// clip's duration, backed by `just_audio`.
class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.url, required this.mine});

  final String url;
  final bool mine;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _playing = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _playerStateSub = _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _playing = s.playing);
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
    _positionSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final dur = await _player.setUrl(widget.url);
      _loaded = true;
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    await _ensureLoaded();
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _position > Duration.zero ? _position : _duration;
    final color = widget.mine ? Colors.white : KliqColors.cyan;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
            size: 32,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _format(shown),
          style: TextStyle(
              fontSize: 12,
              color: widget.mine ? Colors.white70 : KliqColors.textMuted),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../common/people_picker_sheet.dart';
import '../discover/discover_common.dart';

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
  final _composer = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _other = {};
  String? _threadId;
  bool _loading = true;
  StreamSubscription? _wsSub;

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
    _composer.dispose();
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
    if (e['type'] == 'message:new' &&
        _threadId != null &&
        e['threadId']?.toString() == _threadId) {
      final copy = Map<String, dynamic>.from(e)..remove('type');
      if (mounted) setState(() => _messages.add(copy));
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

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    final myId = context.read<Session>().userId;
    _composer.clear();
    setState(() {
      _messages.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'senderId': myId,
        'body': body,
        'createdAt': DateTime.now().toIso8601String(),
        'isMine': true,
      });
    });

    try {
      if (widget.isGroup) {
        await Api.instance.post(
            '/groups/${widget.conversationId}/messages',
            body: {'body': body});
      } else {
        final res = await Api.instance.post('/messages/send', body: {
          if (_threadId != null)
            'threadId': _threadId
          else
            'recipientId': widget.conversationId,
          'body': body,
        });
        final threadId = asMap(res)['threadId']?.toString();
        if (threadId != null) _threadId = threadId;
      }
    } catch (_) {}
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
                      return Align(
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
                          child: Text(pickStr(m, ['body']),
                              style: const TextStyle(fontSize: 14)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      onSubmitted: (_) => _send(),
                      decoration:
                          const InputDecoration(hintText: 'Message…'),
                    ),
                  ),
                  IconButton(
                      icon:
                          const Icon(Icons.send, color: KliqColors.cyan),
                      onPressed: _send),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

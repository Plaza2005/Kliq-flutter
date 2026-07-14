import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../discover/discover_common.dart';

/// Direct messaging: inbox of conversations + 1:1 chat (group chat reuses
/// the same thread widget).

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

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/messages/conversations');
      if (mounted) {
        setState(() {
          _conversations = asMapList(data, key: 'conversations');
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens a searchable people picker; selecting someone opens a chat with them
  /// (ChatPage resolves a userId into a get-or-create thread, same as profiles).
  Future<void> _startChat() async {
    final userId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KliqColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _StartChatSheet(),
    );
    if (userId != null && mounted) {
      await context.push('/chat/$userId');
      _load(); // refresh the inbox when returning
    }
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
                      final other = asMap(c['user'] ?? c['other']);
                      final unread = pickInt(c, ['unreadCount']);
                      return ListTile(
                        leading: KliqAvatar(
                            other['avatarUrl']?.toString(),
                            radius: 22),
                        title: Text(
                            pickStr(other, ['displayName', 'username']),
                            style: TextStyle(
                                fontWeight: unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600)),
                        subtitle: Text(pickStr(c, ['lastMessage']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: unread > 0
                                    ? KliqColors.textPrimary
                                    : KliqColors.textMuted,
                                fontSize: 12.5)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                timeAgo(
                                    c['lastMessageAt']?.toString()),
                                style: const TextStyle(
                                    color: KliqColors.textMuted,
                                    fontSize: 11)),
                            if (unread > 0) ...[
                              const SizedBox(height: 4),
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: KliqColors.pink,
                                child: Text('$unread',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                        onTap: () =>
                            context.push('/chat/${c['id']}'),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Bottom sheet that searches app users and returns the picked user's id.
class _StartChatSheet extends StatefulWidget {
  const _StartChatSheet();

  @override
  State<_StartChatSheet> createState() => _StartChatSheetState();
}

class _StartChatSheetState extends State<_StartChatSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await Api.instance.get('/users/search', query: {'q': q});
      if (!mounted) return;
      setState(() {
        _results = asMapList(data, key: 'users');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
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
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Search people to message',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.contacts_outlined,
                  color: KliqColors.cyan),
              title: const Text('Find contacts'),
              subtitle: const Text('See which friends are already on KLIQ',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/contacts');
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const CenterSpinner()
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _query.text.trim().isEmpty
                                ? 'Search for someone to start a chat'
                                : 'No people found',
                            style: const TextStyle(
                                color: KliqColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final u = _results[i];
                            return ListTile(
                              leading: KliqAvatar(
                                  u['avatarUrl']?.toString(),
                                  radius: 20),
                              title: Text(
                                  pickStr(u, ['displayName', 'username']),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text('@${u['username'] ?? ''}',
                                  style: const TextStyle(
                                      color: KliqColors.textMuted,
                                      fontSize: 12)),
                              onTap: () => Navigator.of(context)
                                  .pop(u['id']?.toString()),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.conversationId, this.isGroup = false});

  final String conversationId;
  final bool isGroup;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _composer = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _other = {};
  bool _loading = true;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _wsSub = WsService.instance.events.listen((e) {
      if (e['type'] == 'message' &&
          (e['conversationId'] == widget.conversationId)) {
        final msg = asMap(e['message'] ?? e);
        if (mounted) setState(() => _messages.add(msg));
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final convs = await Api.instance
          .get('/messages/conversations')
          .catchError((_) => []);
      _other = asMap(asMapList(convs, key: 'conversations')
              .where((c) => c['id'] == widget.conversationId)
              .firstOrNull?['user'] ??
          {});
      final data =
          await Api.instance.get('/messages/${widget.conversationId}');
      if (mounted) {
        setState(() {
          _messages = asMapList(data, key: 'messages');
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    final myId = context.read<Session>().userId;
    setState(() {
      _messages.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'senderId': myId,
        'body': body,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _composer.clear();
    Api.instance
        .post('/messages/${widget.conversationId}', body: {'body': body})
        .catchError((_) => null);
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

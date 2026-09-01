import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_service.dart';
import '../discover/discover_common.dart';

/// Minimal community chat surface: a shared, many-to-many message stream for
/// a community (distinct from 1:1 DM threads and private group chats).
/// Wired to GET/POST /communities/:id/messages.
class CommunityChatPage extends StatefulWidget {
  const CommunityChatPage({super.key, required this.communityId});

  final String communityId;

  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  final _composer = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  String _title = 'Community';
  bool _loading = true;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _wsSub = WsService.instance.events.listen((e) {
      if (e['type'] == 'community:message' &&
          e['communityId']?.toString() == widget.communityId) {
        final msg = asMap(e['message']);
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
      final info = await Api.instance
          .get('/communities/${widget.communityId}')
          .catchError((_) => null);
      final infoMap = asMap(info);
      final data =
          await Api.instance.get('/communities/${widget.communityId}/messages');
      if (mounted) {
        setState(() {
          if (infoMap.isNotEmpty) {
            _title = pickStr(infoMap, ['name'], fallback: 'Community');
          }
          _messages = asMapList(data);
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
    _composer.clear();
    try {
      final res = await Api.instance.post(
          '/communities/${widget.communityId}/messages',
          body: {'body': body});
      if (mounted) setState(() => _messages.add(asMap(res)));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const CenterSpinner()
                : _messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'No messages yet',
                        subtitle: 'Say hello to the community')
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[_messages.length - 1 - i];
                          final author = asMap(m['author']);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                KliqAvatar(author['avatarUrl']?.toString(),
                                    radius: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          pickStr(
                                              author,
                                              ['displayName', 'username'],
                                              fallback: 'KLIQ user'),
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(pickStr(m, ['body']),
                                          style:
                                              const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
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
                      decoration: const InputDecoration(
                          hintText: 'Message the community…'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: KliqColors.cyan),
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

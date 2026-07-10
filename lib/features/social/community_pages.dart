import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// Communities: themed group spaces with channels, join/leave, chat and
/// creation flow.

class CommunitiesPage extends StatefulWidget {
  const CommunitiesPage({super.key});

  @override
  State<CommunitiesPage> createState() => _CommunitiesPageState();
}

class _CommunitiesPageState extends State<CommunitiesPage> {
  List<Map<String, dynamic>> _communities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/communities');
      if (mounted) {
        setState(() {
          _communities = asMapList(data, key: 'communities');
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Communities',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/create-community')),
        ],
      ),
      body: _loading
          ? const CenterSpinner()
          : _communities.isEmpty
              ? EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No communities yet',
                  actionLabel: 'Create one',
                  onAction: () => context.push('/create-community'))
              : RefreshIndicator(
                  color: KliqColors.cyan,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _communities.length,
                    itemBuilder: (context, i) {
                      final c = _communities[i];
                      return Card(
                        color: KliqColors.surface,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side:
                              const BorderSide(color: KliqColors.border),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                                width: 52,
                                height: 52,
                                child:
                                    NetImg(c['avatarUrl']?.toString())),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(pickStr(c, ['name']),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (c['isPrivate'] == true) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.lock,
                                    size: 13,
                                    color: KliqColors.textMuted),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${fmtCount(pickInt(c, ['memberCount']))} members · ${pickStr(c, ['description'])}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: KliqColors.textMuted,
                                fontSize: 12),
                          ),
                          trailing: c['isJoined'] == true
                              ? const Icon(Icons.check_circle,
                                  color: KliqColors.success, size: 20)
                              : null,
                          onTap: () =>
                              context.push('/community/${c['id']}'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.communityId});

  final String communityId;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  Map<String, dynamic>? _community;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await Api.instance.get('/communities/${widget.communityId}');
      if (mounted) {
        setState(() {
          _community = asMap(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleJoin() async {
    final c = _community;
    if (c == null) return;
    setState(() => c['isJoined'] = !(c['isJoined'] as bool? ?? false));
    Api.instance
        .post('/communities/${widget.communityId}/join')
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    final c = _community ?? {};
    final channels = (c['channels'] as List?)?.cast<String>() ??
        const ['General', 'Announcements', 'Media', 'Events', 'Off-topic'];
    final joined = c['isJoined'] == true;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NetImg(pickStr(c, ['bannerUrl', 'avatarUrl'])),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pickStr(c, ['name']),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      '${fmtCount(pickInt(c, ['memberCount']))} members',
                      style: const TextStyle(
                          color: KliqColors.textMuted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Text(pickStr(c, ['description']),
                      style: const TextStyle(
                          color: KliqColors.textSecondary,
                          fontSize: 13.5)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient:
                                joined ? null : KliqColors.gradient,
                            color: joined
                                ? KliqColors.surfaceElevated
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextButton(
                            onPressed: _toggleJoin,
                            child: Text(joined ? 'Joined ✓' : 'Join',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KliqColors.textPrimary,
                          side:
                              const BorderSide(color: KliqColors.border),
                        ),
                        onPressed: () => context.push(
                            '/community/${widget.communityId}/chat'),
                        icon: const Icon(Icons.chat_bubble_outline,
                            size: 17),
                        label: const Text('Chat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Channels',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: channels.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.tag, color: KliqColors.textMuted),
              title: Text(channels[i]),
              trailing: const Icon(Icons.chevron_right,
                  color: KliqColors.textMuted),
              onTap: () => context.push(
                  '/community/${widget.communityId}/chat?channel=${channels[i]}'),
            ),
          ),
        ],
      ),
    );
  }
}

class CommunityChatPage extends StatefulWidget {
  const CommunityChatPage(
      {super.key, required this.communityId, this.channel});

  final String communityId;
  final String? channel;

  @override
  State<CommunityChatPage> createState() => _CommunityChatPageState();
}

class _CommunityChatPageState extends State<CommunityChatPage> {
  final _composer = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance
          .get('/communities/${widget.communityId}/messages');
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
    final me = context.read<Session>().user ?? {};
    setState(() {
      _messages.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'author': me,
        'body': body,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _composer.clear();
    Api.instance
        .post('/communities/${widget.communityId}/messages',
            body: {'body': body, 'channel': widget.channel})
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<Session>().userId;
    return Scaffold(
      appBar: AppBar(
          title: Text('#${widget.channel ?? 'General'}',
              style: const TextStyle(fontSize: 16))),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const CenterSpinner()
                : _messages.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        subtitle: 'Start the conversation!')
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m =
                              _messages[_messages.length - 1 - i];
                          final author = authorOf(m);
                          final mine =
                              asMap(m['author'])['id'] == myId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: mine
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (!mine) ...[
                                  KliqAvatar(author['avatarUrl'],
                                      radius: 14),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? KliqColors.cyan
                                              .withValues(alpha: 0.25)
                                          : KliqColors.surfaceElevated,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!mine)
                                          Text(author['username']!,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color:
                                                      KliqColors.cyan)),
                                        Text(pickStr(m, ['body'])),
                                      ],
                                    ),
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
                      icon: const Icon(Icons.send,
                          color: KliqColors.cyan),
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

class CreateCommunityPage extends StatefulWidget {
  const CreateCommunityPage({super.key});

  @override
  State<CreateCommunityPage> createState() => _CreateCommunityPageState();
}

class _CreateCommunityPageState extends State<CreateCommunityPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _privacy = 'public';
  bool _busy = false;

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your community a name')));
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final res = await Api.instance.post('/communities', body: {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'privacy': _privacy,
      });
      messenger.showSnackBar(
          const SnackBar(content: Text('Community created 🎉')));
      final id = (res is Map) ? res['id']?.toString() : null;
      if (id != null) {
        router.pushReplacement('/community/$id');
      } else {
        router.pop();
      }
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Creation failed: $e')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Community')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              decoration:
                  const InputDecoration(hintText: 'Community name')),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration:
                const InputDecoration(hintText: 'What is it about?'),
          ),
          const SizedBox(height: 14),
          const Text('Privacy',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in const ['public', 'private', 'invite-only'])
                ChoiceChip(
                  label: Text(p),
                  selected: _privacy == p,
                  selectedColor: KliqColors.cyan.withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _privacy = p),
                ),
            ],
          ),
          const SizedBox(height: 20),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: KliqColors.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _busy ? null : _create,
              child: Text(_busy ? 'Creating…' : 'Create Community',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// Result returned by [showPeoplePickerSheet]: either a set of selected
/// users, or a request to create a promotional community instead.
///
/// Callers decide what "1 selected" vs "many selected" vs "community" means
/// (e.g. inbox: 1 -> DM, many -> group chat; a later Share phase may treat
/// selection differently) — this widget only handles picking.
class PeoplePickerResult {
  const PeoplePickerResult.users(this.users) : createCommunity = false;
  const PeoplePickerResult.community()
      : users = const [],
        createCommunity = true;

  final List<Map<String, dynamic>> users;
  final bool createCommunity;
}

/// Shared multi-select user-search sheet. Generalises the old single-select
/// "start chat" sheet so it can be reused anywhere the app needs to pick one
/// or more people — the inbox's "start chat" flow today, and a future Share
/// feature. Not inbox-specific in its API: it just returns a selection.
class PeoplePickerSheet extends StatefulWidget {
  const PeoplePickerSheet({
    super.key,
    this.title = 'New message',
    this.allowCommunityCreation = true,
    this.confirmLabel = 'Chat',
  });

  final String title;
  final bool allowCommunityCreation;
  final String confirmLabel;

  @override
  State<PeoplePickerSheet> createState() => _PeoplePickerSheetState();
}

class _PeoplePickerSheetState extends State<PeoplePickerSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  final Map<String, Map<String, dynamic>> _selected = {};
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

  void _toggle(Map<String, dynamic> u) {
    final id = u['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else {
        _selected[id] = u;
      }
    });
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(PeoplePickerResult.users(_selected.values.toList()));
  }

  void _pickCommunity() {
    Navigator.of(context).pop(const PeoplePickerResult.community());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: _confirm,
                      child: Text(_selected.length == 1
                          ? widget.confirmLabel
                          : 'Create group (${_selected.length})'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Search people',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (_selected.isNotEmpty)
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: _selected.values.map((u) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              KliqAvatar(u['avatarUrl']?.toString(), radius: 24),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: GestureDetector(
                                  onTap: () => _toggle(u),
                                  child: const CircleAvatar(
                                    radius: 9,
                                    backgroundColor: KliqColors.danger,
                                    child: Icon(Icons.close,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 56,
                            child: Text(
                              pickStr(u, ['displayName', 'username']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (widget.allowCommunityCreation) ...[
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined,
                    color: KliqColors.pink),
                title: const Text('Create a community'),
                subtitle: const Text(
                    'Public promotional space anyone can join',
                    style: TextStyle(fontSize: 12)),
                onTap: _pickCommunity,
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: _loading
                  ? const CenterSpinner()
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _query.text.trim().isEmpty
                                ? 'Search for people to add'
                                : 'No people found',
                            style:
                                const TextStyle(color: KliqColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final u = _results[i];
                            final id = u['id']?.toString();
                            final checked =
                                id != null && _selected.containsKey(id);
                            return ListTile(
                              leading: KliqAvatar(
                                  u['avatarUrl']?.toString(), radius: 20),
                              title: Text(
                                  pickStr(u, ['displayName', 'username']),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text('@${u['username'] ?? ''}',
                                  style: const TextStyle(
                                      color: KliqColors.textMuted,
                                      fontSize: 12)),
                              trailing: Icon(
                                checked
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: checked
                                    ? KliqColors.cyan
                                    : KliqColors.textMuted,
                              ),
                              onTap: () => _toggle(u),
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

/// Opens [PeoplePickerSheet] and returns the user's choice, or null if
/// dismissed without picking anything.
Future<PeoplePickerResult?> showPeoplePickerSheet(
  BuildContext context, {
  String title = 'New message',
  bool allowCommunityCreation = true,
  String confirmLabel = 'Chat',
}) {
  return showModalBottomSheet<PeoplePickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KliqColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PeoplePickerSheet(
      title: title,
      allowCommunityCreation: allowCommunityCreation,
      confirmLabel: confirmLabel,
    ),
  );
}

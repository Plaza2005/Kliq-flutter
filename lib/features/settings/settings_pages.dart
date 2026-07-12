import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// Settings root + sub-pages (privacy, notification prefs, blocked, muted,
/// language) and the sign-out action.

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        children: [
          _tile(context, Icons.person_outline, 'Edit profile',
              '/edit-profile'),
          _tile(context, Icons.lock_outline, 'Privacy',
              '/settings/privacy'),
          _tile(context, Icons.notifications_outlined,
              'Notification preferences', '/settings/notifications'),
          _tile(context, Icons.block_outlined, 'Blocked users',
              '/settings/blocked'),
          _tile(context, Icons.volume_off_outlined, 'Muted users',
              '/settings/muted'),
          _tile(context, Icons.language_outlined, 'Language & region',
              '/settings/language'),
          _tile(context, Icons.bookmark_border, 'Saved posts', '/saved'),
          _tile(context, Icons.people_outline, 'Friends', '/friends'),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.logout, color: KliqColors.danger),
            title: const Text('Sign out',
                style: TextStyle(color: KliqColors.danger)),
            onTap: () async {
              final router = GoRouter.of(context);
              await session.logout();
              router.go('/login');
            },
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('KLIQ · Made in Namibia 🇳🇦',
                style:
                    TextStyle(color: KliqColors.textMuted, fontSize: 12)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: KliqColors.textSecondary),
      title: Text(label),
      trailing:
          const Icon(Icons.chevron_right, color: KliqColors.textMuted),
      onTap: () => context.push(route),
    );
  }
}

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _privateAccount = false;
  bool _showActivity = true;
  bool _allowMessages = true;
  bool _allowTags = true;

  void _save(String key, bool value) {
    Api.instance
        .patch('/users/privacy', body: {key: value}).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Private account'),
            subtitle: const Text('Only approved followers see your posts',
                style: TextStyle(color: KliqColors.textMuted, fontSize: 12)),
            value: _privateAccount,
            activeThumbColor: KliqColors.cyan,
            onChanged: (v) {
              setState(() => _privateAccount = v);
              _save('privateAccount', v);
            },
          ),
          SwitchListTile(
            title: const Text('Show activity status'),
            value: _showActivity,
            activeThumbColor: KliqColors.cyan,
            onChanged: (v) {
              setState(() => _showActivity = v);
              _save('showActivity', v);
            },
          ),
          SwitchListTile(
            title: const Text('Allow messages from everyone'),
            value: _allowMessages,
            activeThumbColor: KliqColors.cyan,
            onChanged: (v) {
              setState(() => _allowMessages = v);
              _save('allowMessages', v);
            },
          ),
          SwitchListTile(
            title: const Text('Allow tags & mentions'),
            value: _allowTags,
            activeThumbColor: KliqColors.cyan,
            onChanged: (v) {
              setState(() => _allowTags = v);
              _save('allowTags', v);
            },
          ),
        ],
      ),
    );
  }
}

class NotificationPrefsPage extends StatefulWidget {
  const NotificationPrefsPage({super.key});

  @override
  State<NotificationPrefsPage> createState() => _NotificationPrefsPageState();
}

class _NotificationPrefsPageState extends State<NotificationPrefsPage> {
  final _prefs = <String, bool>{
    'Likes': true,
    'Comments': true,
    'New followers': true,
    'Direct messages': true,
    'Live streams': true,
    'Marketplace orders': true,
    'Community activity': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        children: [
          for (final e in _prefs.entries)
            SwitchListTile(
              title: Text(e.key),
              value: e.value,
              activeThumbColor: KliqColors.cyan,
              onChanged: (v) {
                setState(() => _prefs[e.key] = v);
                Api.instance.patch('/notifications/prefs',
                    body: {e.key: v}).catchError((_) => null);
              },
            ),
        ],
      ),
    );
  }
}

class _UserListSettingsPage extends StatelessWidget {
  const _UserListSettingsPage(
      {required this.title, required this.endpoint, required this.emptyLabel});

  final String title;
  final String endpoint;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder(
        future: Api.instance.get(endpoint).catchError((_) => []),
        builder: (context, snap) {
          if (!snap.hasData) return const CenterSpinner();
          final users = asMapList(snap.data, key: 'users');
          if (users.isEmpty) {
            return EmptyState(
                icon: Icons.person_off_outlined, title: emptyLabel);
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: KliqAvatar(u['avatarUrl']?.toString()),
                title: Text(pickStr(u, ['displayName', 'username'])),
                subtitle: Text('@${pickStr(u, ['username'])}',
                    style:
                        const TextStyle(color: KliqColors.textMuted)),
                trailing: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed')));
                  },
                  child: const Text('Remove',
                      style: TextStyle(color: KliqColors.cyan)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) => const _UserListSettingsPage(
      title: 'Blocked Users',
      endpoint: '/blocks',
      emptyLabel: 'You have not blocked anyone');
}

class MutedUsersPage extends StatelessWidget {
  const MutedUsersPage({super.key});

  @override
  Widget build(BuildContext context) => const _UserListSettingsPage(
      title: 'Muted Users',
      endpoint: '/blocks/muted',
      emptyLabel: 'You have not muted anyone');
}

class LanguageRegionPage extends StatefulWidget {
  const LanguageRegionPage({super.key});

  @override
  State<LanguageRegionPage> createState() => _LanguageRegionPageState();
}

class _LanguageRegionPageState extends State<LanguageRegionPage> {
  String _language = 'English';
  String _region = 'Namibia';

  static const _languages = [
    'English', 'Oshiwambo', 'Otjiherero', 'Afrikaans', 'Portuguese'
  ];
  static const _regions = [
    'Namibia', 'South Africa', 'Botswana', 'Angola', 'Zambia', 'Other'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language & Region')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Language',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in _languages)
                ChoiceChip(
                  label: Text(l),
                  selected: _language == l,
                  selectedColor: KliqColors.cyan.withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _language = l),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Region',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _regions)
                ChoiceChip(
                  label: Text(r),
                  selected: _region == r,
                  selectedColor: KliqColors.pink.withValues(alpha: 0.3),
                  onSelected: (_) => setState(() => _region = r),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

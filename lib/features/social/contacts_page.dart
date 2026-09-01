import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// "Find contacts" — matches the device's contacts against KLIQ accounts
/// (by phone/email) so the user can follow/message people they already know,
/// or invite the rest. Contacts never leave the device except as the phone
/// numbers/emails posted to /users/match-contacts for this one lookup; the
/// server does not persist them.
///
/// flutter_contacts has no web implementation, so on web this page just
/// explains that the feature is mobile-only.
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool _loading = true;
  bool _permissionDenied = false;
  String? _error;
  List<Map<String, dynamic>> _matched = [];
  List<Contact> _inviteContacts = [];

  /// Maps a raw phone number / email string (exactly as read from the
  /// device) back to the contact it came from, so matched users can be
  /// labelled "From your contacts: name".
  final Map<String, Contact> _contactByValue = {};

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _permissionDenied = false;
    });
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
          _loading = false;
        });
        return;
      }

      final contacts = await FlutterContacts.getContacts(withProperties: true);

      _contactByValue.clear();
      final phones = <String>[];
      final emails = <String>[];
      for (final c in contacts) {
        for (final p in c.phones) {
          if (p.number.trim().isEmpty) continue;
          phones.add(p.number);
          _contactByValue[p.number] = c;
        }
        for (final e in c.emails) {
          if (e.address.trim().isEmpty) continue;
          emails.add(e.address);
          _contactByValue[e.address] = c;
        }
      }

      final data = await Api.instance.post('/users/match-contacts',
          body: {'phones': phones, 'emails': emails});
      final matched = asMapList(data, key: 'users');
      final matchedValues = matched
          .map((u) => u['matchedOn']?.toString())
          .whereType<String>()
          .toSet();

      final invite = contacts.where((c) {
        final values = [
          ...c.phones.map((p) => p.number),
          ...c.emails.map((e) => e.address),
        ].where((v) => v.trim().isNotEmpty);
        if (values.isEmpty) return false;
        return !values.any(matchedValues.contains);
      }).toList()
        ..sort((a, b) => a.displayName
            .toLowerCase()
            .compareTo(b.displayName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _matched = matched;
        _inviteContacts = invite;
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

  Future<void> _toggleFollow(Map<String, dynamic> u) async {
    final id = u['id']?.toString();
    if (id == null) return;
    setState(() => u['isFollowing'] = u['isFollowing'] != true);
    try {
      await Api.instance.post('/users/$id/follow');
    } catch (_) {
      if (mounted) setState(() => u['isFollowing'] = u['isFollowing'] != true);
    }
  }

  void _openInviteSheet(Contact contact) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
    final email = contact.emails.isNotEmpty ? contact.emails.first.address : null;
    showModalBottomSheet(
      context: context,
      backgroundColor: KliqColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _InviteSheet(contact: contact, phone: phone, email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Find contacts')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Available on the mobile app',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: KliqColors.textSecondary, fontSize: 15),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Find contacts')),
      body: _loading
          ? const CenterSpinner()
          : _permissionDenied
              ? EmptyState(
                  icon: Icons.contacts_outlined,
                  title: 'Contacts permission needed',
                  subtitle:
                      'Allow contacts access so KLIQ can find friends you already know',
                  actionLabel: 'Retry',
                  onAction: _load,
                )
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : (_matched.isEmpty && _inviteContacts.isEmpty)
                      ? const EmptyState(
                          icon: Icons.contacts_outlined,
                          title: 'No contacts found',
                          subtitle:
                              "We couldn't find any contacts with a phone number or email",
                        )
                      : RefreshIndicator(
                          color: KliqColors.cyan,
                          onRefresh: _load,
                          child: ListView(
                            children: [
                              if (_matched.isNotEmpty) ...[
                                _sectionHeader('On KLIQ'),
                                for (final u in _matched) _matchedTile(u),
                              ],
                              if (_inviteContacts.isNotEmpty) ...[
                                _sectionHeader('Invite to KLIQ'),
                                for (final c in _inviteContacts)
                                  _inviteTile(c),
                              ],
                            ],
                          ),
                        ),
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: KliqColors.textSecondary)),
      );

  Widget _matchedTile(Map<String, dynamic> u) {
    final contact = _contactByValue[u['matchedOn']?.toString()];
    final following = u['isFollowing'] == true;
    final id = u['id']?.toString() ?? '';
    return ListTile(
      leading: KliqAvatar(u['avatarUrl']?.toString()),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(pickStr(u, ['displayName', 'username']),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (u['isVerified'] == true) ...[
            const SizedBox(width: 4),
            const Icon(Icons.verified, size: 14, color: KliqColors.cyan),
          ],
        ],
      ),
      subtitle: Text(
          contact != null
              ? 'From your contacts: ${contact.displayName}'
              : '@${pickStr(u, ['username'])}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: KliqColors.textMuted, fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: following ? null : KliqColors.gradient,
              color: following ? KliqColors.surfaceElevated : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => _toggleFollow(u),
              child: Text(following ? 'Following' : 'Follow',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(
            tooltip: 'Message',
            icon: const Icon(Icons.send_outlined,
                color: KliqColors.cyan, size: 20),
            onPressed: id.isEmpty ? null : () => context.push('/chat/$id'),
          ),
        ],
      ),
    );
  }

  Widget _inviteTile(Contact c) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: KliqColors.surfaceElevated,
        child: Icon(Icons.person_outline, color: KliqColors.textMuted),
      ),
      title: Text(c.displayName.isEmpty ? 'Unknown' : c.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: KliqColors.textPrimary,
          side: const BorderSide(color: KliqColors.border),
        ),
        onPressed: () => _openInviteSheet(c),
        child: const Text('Invite'),
      ),
    );
  }
}

/// Bottom sheet with the invite channels for one contact.
class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.contact, this.phone, this.email});

  final Contact contact;
  final String? phone;
  final String? email;

  String get _inviteText => 'Join me on KLIQ! $kInviteUrl';

  Future<void> _sms(BuildContext context) async {
    final number = phone;
    if (number == null) return;
    Navigator.of(context).pop();
    final uri =
        Uri.parse('sms:$number?body=${Uri.encodeComponent(_inviteText)}');
    await launchUrl(uri);
  }

  Future<void> _email(BuildContext context) async {
    final address = email;
    if (address == null) return;
    Navigator.of(context).pop();
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query:
          'subject=${Uri.encodeComponent('Join me on KLIQ')}&body=${Uri.encodeComponent(_inviteText)}',
    );
    await launchUrl(uri);
  }

  Future<void> _whatsapp(BuildContext context) async {
    Navigator.of(context).pop();
    final digits = phone?.replaceAll(RegExp(r'\D'), '');
    final uri = (digits != null && digits.isNotEmpty)
        ? Uri.parse(
            'https://wa.me/$digits?text=${Uri.encodeComponent(_inviteText)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_inviteText)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Instagram has no reliable "share this text" deep link, so this opens
  /// the OS share sheet (which lists Instagram alongside everything else)
  /// via share_plus.
  Future<void> _more(BuildContext context) async {
    Navigator.of(context).pop();
    await SharePlus.instance.share(ShareParams(text: _inviteText));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Invite ${contact.displayName.isEmpty ? 'contact' : contact.displayName}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined, color: KliqColors.cyan),
            title: const Text('SMS'),
            enabled: phone != null,
            onTap: phone == null ? null : () => _sms(context),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined, color: KliqColors.cyan),
            title: const Text('Email'),
            enabled: email != null,
            onTap: email == null ? null : () => _email(context),
          ),
          ListTile(
            leading:
                const Icon(Icons.chat_bubble_outline, color: KliqColors.cyan),
            title: const Text('WhatsApp'),
            onTap: () => _whatsapp(context),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined, color: KliqColors.cyan),
            title: const Text('More / Instagram'),
            onTap: () => _more(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

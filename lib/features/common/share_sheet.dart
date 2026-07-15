import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart' show pickStr;
import 'people_picker_sheet.dart';

/// Minimal description of the post/reel being shared. Deliberately decoupled
/// from the [Post] model (home feed uses a typed model, reels use raw
/// `Map<String, dynamic>`s) so one sheet works for both callers.
class ShareTarget {
  const ShareTarget({
    required this.postId,
    required this.authorUsername,
    this.caption = '',
    this.mediaUrl,
    this.mediaType,
  });

  final String postId;
  final String authorUsername;
  final String caption;

  /// Server-relative or absolute media URL (first image/video of the post),
  /// or null for a text-only post.
  final String? mediaUrl;

  /// 'image' | 'video' | null.
  final String? mediaType;

  String get link => '$kInviteUrl/post/$postId';
}

/// Opens the share bottom sheet for [target]. [onShared] fires after any
/// share path that we could confirm was at least attempted (in-app send, or
/// an external share sheet/deep link was invoked) so the caller can bump its
/// locally displayed share count without waiting on a second network call.
Future<void> showShareSheet(
  BuildContext context, {
  required ShareTarget target,
  VoidCallback? onShared,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: KliqColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ShareSheet(target: target, onShared: onShared),
  );
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.target, this.onShared});

  final ShareTarget target;
  final VoidCallback? onShared;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  final _message = TextEditingController();
  bool _sendingInApp = false;
  bool _sendingExternal = false;

  ShareTarget get target => widget.target;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  static String _truncate(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}…';

  /// Text body used for in-app messages and text-capable external targets:
  /// optional user message, then attribution + caption preview, then link.
  String _composeBody() {
    final parts = <String>[];
    final msg = _message.text.trim();
    if (msg.isNotEmpty) parts.add(msg);
    final caption = target.caption.trim();
    parts.add(caption.isEmpty
        ? 'Shared a post from @${target.authorUsername}'
        : 'Shared a post from @${target.authorUsername}: "${_truncate(caption, 140)}"');
    parts.add(target.link);
    return parts.join('\n');
  }

  /// Best-effort: bumps Post.shareCount. Failure here shouldn't surface an
  /// error to the user — the share itself already happened/was attempted.
  Future<void> _bumpShareCount() async {
    try {
      await Api.instance.post('/posts/${target.postId}/share');
    } catch (_) {
      // Non-fatal — ranking signal only.
    }
    widget.onShared?.call();
  }

  // ── In-app share: reuse the Phase 4 people picker ─────────────────────

  Future<void> _sendInApp() async {
    if (_sendingInApp) return;
    final result = await showPeoplePickerSheet(
      context,
      title: 'Send to',
      confirmLabel: 'Send',
    );
    if (result == null || !mounted) return;

    final onShared = widget.onShared;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sendingInApp = true);
    try {
      final body = _composeBody();

      if (result.createCommunity) {
        final community = await Api.instance.post('/communities', body: {
          'name': "@${target.authorUsername}'s post",
        });
        final id = (community is Map ? community['id'] : null)?.toString();
        if (id == null || id.isEmpty) {
          throw ApiException('Community was not created');
        }
        await Api.instance
            .post('/communities/$id/messages', body: {'body': body});
      } else if (result.users.length == 1) {
        final recipientId = result.users.first['id']?.toString();
        if (recipientId == null || recipientId.isEmpty) {
          throw ApiException('No recipient selected');
        }
        await Api.instance.post('/messages/send', body: {
          'recipientId': recipientId,
          'body': body,
          if (target.mediaUrl != null) 'mediaUrl': target.mediaUrl,
          if (target.mediaUrl != null)
            'mediaType': target.mediaType ?? 'image',
        });
      } else if (result.users.length > 1) {
        final memberUsernames = result.users
            .map((u) => u['username']?.toString())
            .whereType<String>()
            .toList();
        final name = result.users
            .map((u) => pickStr(u, ['displayName', 'username']))
            .join(', ');
        final group = await Api.instance.post('/groups', body: {
          'name': name,
          'memberUsernames': memberUsernames,
        });
        final id = (group is Map ? group['id'] : null)?.toString();
        if (id == null || id.isEmpty) {
          throw ApiException('Group was not created');
        }
        await Api.instance.post('/groups/$id/messages', body: {'body': body});
      } else {
        // Nothing selected (shouldn't happen — picker requires a selection).
        if (mounted) setState(() => _sendingInApp = false);
        return;
      }

      try {
        await Api.instance.post('/posts/${target.postId}/share');
      } catch (_) {
        // Non-fatal — the message already sent; shareCount is a ranking
        // signal only.
      }
      onShared?.call();
      messenger.showSnackBar(const SnackBar(content: Text('Shared')));
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Could not share: $e')));
        setState(() => _sendingInApp = false);
      }
    }
  }

  // ── External apps ──────────────────────────────────────────────────────

  /// WhatsApp, Telegram and SMS accept prefilled text + a link via their own
  /// URL schemes, so those deep-link straight into the named app (matching
  /// the pattern already used by contacts_page.dart's invite sheet) rather
  /// than opening a generic chooser that share_plus alone can't target to
  /// one specific app.
  Future<void> _shareViaUrl(Uri uri) async {
    Navigator.of(context).pop();
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) await _bumpShareCount();
    } catch (_) {
      // Sheet is already dismissed by this point — nothing sensible to show;
      // the OS not having a handler for this scheme is the caller's problem,
      // not ours, and shareCount simply won't bump.
    }
  }

  Future<void> _shareWhatsApp() =>
      _shareViaUrl(Uri.parse(
          'https://wa.me/?text=${Uri.encodeComponent(_composeBody())}'));

  Future<void> _shareTelegram() {
    final msg = _message.text.trim().isEmpty
        ? 'Shared a post from @${target.authorUsername}'
        : _message.text.trim();
    return _shareViaUrl(Uri.parse(
        'https://t.me/share/url?url=${Uri.encodeComponent(target.link)}&text=${Uri.encodeComponent(msg)}'));
  }

  Future<void> _shareSms() => _shareViaUrl(
      Uri.parse('sms:?body=${Uri.encodeComponent(_composeBody())}'));

  /// Instagram and TikTok's share-sheet intents accept media but not
  /// prefilled caption text, so this downloads the post's media and hands
  /// it to the OS share sheet as a file only — no message field. If the
  /// post has no media (a text post) there's nothing these two can accept.
  Future<void> _shareMedia(String label) async {
    final mediaUrl = target.mediaUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('This post has no photo or video for $label to share')));
      return;
    }
    if (_sendingExternal) return;
    setState(() => _sendingExternal = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final url = Api.instance.mediaUrl(mediaUrl);
      final isVideo = target.mediaType == 'video';
      final response = await dio.Dio().get<List<int>>(
        url,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null) throw ApiException('Could not download media');
      final xfile = XFile.fromData(
        Uint8List.fromList(bytes),
        name: isVideo ? 'kliq_share.mp4' : 'kliq_share.jpg',
        mimeType: isVideo ? 'video/mp4' : 'image/jpeg',
      );
      navigator.pop();
      await SharePlus.instance.share(ShareParams(files: [xfile]));
      await _bumpShareCount();
    } catch (e) {
      if (mounted) {
        messenger
            .showSnackBar(SnackBar(content: Text('Could not share media: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingExternal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasMedia = target.mediaUrl != null && target.mediaUrl!.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Share',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _message,
                minLines: 1,
                maxLines: 3,
                enabled: !_sendingInApp && !_sendingExternal,
                decoration:
                    const InputDecoration(hintText: 'Add a message (optional)'),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: KliqColors.surfaceElevated,
                child: Icon(Icons.send_outlined, color: KliqColors.cyan),
              ),
              title: const Text('Send to friend or group'),
              subtitle: const Text('Search people on KLIQ, or create a community',
                  style: TextStyle(fontSize: 12)),
              enabled: !_sendingInApp && !_sendingExternal,
              trailing: _sendingInApp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: (_sendingInApp || _sendingExternal) ? null : _sendInApp,
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Share to',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: KliqColors.textSecondary)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _externalButton(
                    icon: Icons.chat_bubble,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: _shareWhatsApp,
                  ),
                  _externalButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Instagram',
                    color: KliqColors.pink,
                    onTap: () => _shareMedia('Instagram'),
                    busy: _sendingExternal,
                  ),
                  _externalButton(
                    icon: Icons.music_note,
                    label: 'TikTok',
                    color: KliqColors.textPrimary,
                    onTap: () => _shareMedia('TikTok'),
                    busy: _sendingExternal,
                  ),
                  _externalButton(
                    icon: Icons.send,
                    label: 'Telegram',
                    color: const Color(0xFF229ED9),
                    onTap: _shareTelegram,
                  ),
                  _externalButton(
                    icon: Icons.sms_outlined,
                    label: 'SMS',
                    color: KliqColors.cyan,
                    onTap: _shareSms,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                hasMedia
                    ? "Instagram and TikTok only accept the photo/video itself — your message above won't carry over."
                    : 'Instagram and TikTok need a photo or video to share; this post is text-only.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: KliqColors.textMuted, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _externalButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool busy = false,
  }) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.18),
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: KliqColors.textSecondary)),
        ],
      ),
    );
  }
}

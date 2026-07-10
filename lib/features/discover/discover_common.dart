import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

/// Shared helpers for the discovery/video surfaces (Explore, Search, Reels,
/// KliqTube, KliqStream, Sounds). The demo backend and the live Node API
/// return slightly different field names for the same concepts, so every
/// page goes through the tolerant readers below — one code path, two modes.

// ── JSON readers ─────────────────────────────────────────────────────────

/// Unwraps `[...]`, `{posts: [...]}` or the first list value found in a map.
List<Map<String, dynamic>> asMapList(dynamic data, {String key = 'posts'}) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (data is Map) {
    if (data[key] is List) return asMapList(data[key]);
    for (final v in data.values) {
      if (v is List) return asMapList(v);
    }
  }
  return [];
}

Map<String, dynamic> asMap(dynamic data) =>
    data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

/// First non-empty string among [keys].
String pickStr(Map<String, dynamic> m, List<String> keys,
    {String fallback = ''}) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return fallback;
}

int pickInt(Map<String, dynamic> m, List<String> keys, {int fallback = 0}) {
  for (final k in keys) {
    final v = m[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
  }
  return fallback;
}

bool pickBool(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is bool) return v;
  }
  return false;
}

/// Author submap normalised to username/displayName/avatarUrl.
Map<String, String> authorOf(Map<String, dynamic> m) {
  final a = asMap(m['author'] ?? m['user'] ?? m['seller']);
  return {
    'username': pickStr(a, ['username'], fallback: 'kliq'),
    'displayName':
        pickStr(a, ['displayName', 'username'], fallback: 'KLIQ user'),
    'avatarUrl': pickStr(a, ['avatarUrl']),
  };
}

// ── Formatting ───────────────────────────────────────────────────────────

String fmtCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _two(int v) => v.toString().padLeft(2, '0');

String fmtDuration(int seconds) {
  final s = seconds % 60;
  final m = (seconds ~/ 60) % 60;
  final h = seconds ~/ 3600;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

String timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${diff.inDays ~/ 30}mo ago';
  return '${diff.inDays ~/ 365}y ago';
}

// ── Widgets ──────────────────────────────────────────────────────────────

/// Network image that resolves server-relative paths and never throws.
class NetImg extends StatelessWidget {
  const NetImg(this.url, {super.key, this.fit = BoxFit.cover});
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return const _ImgFallback();
    return CachedNetworkImage(
      imageUrl: Api.instance.mediaUrl(url!),
      fit: fit,
      placeholder: (c, u) => const ColoredBox(color: KliqColors.surface),
      errorWidget: (c, u, e) => const _ImgFallback(),
    );
  }
}

class _ImgFallback extends StatelessWidget {
  const _ImgFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: KliqColors.surfaceElevated,
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: KliqColors.textMuted, size: 20),
        ),
      );
}

class KliqAvatar extends StatelessWidget {
  const KliqAvatar(this.url, {super.key, this.radius = 18});
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: KliqColors.surfaceElevated,
      foregroundImage: (url != null && url!.isNotEmpty)
          ? CachedNetworkImageProvider(Api.instance.mediaUrl(url!))
          : null,
      child: Icon(Icons.person, size: radius, color: KliqColors.textMuted),
    );
  }
}

class CenterSpinner extends StatelessWidget {
  const CenterSpinner({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: KliqColors.cyan),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: KliqColors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    color: KliqColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: KliqColors.textSecondary, fontSize: 13)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Something went wrong',
      subtitle: message,
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }
}

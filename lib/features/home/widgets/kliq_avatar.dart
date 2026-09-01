import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';

/// Circular avatar with optional story ring (cyan → pink gradient for
/// unseen stories, muted border otherwise).
class KliqAvatar extends StatelessWidget {
  const KliqAvatar({
    super.key,
    this.url,
    this.size = 40,
    this.ring = false,
    this.ringSeen = false,
    this.onTap,
  });

  final String? url;
  final double size;
  final bool ring;
  final bool ringSeen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget avatar = ClipOval(
      child: (url == null || url!.isEmpty)
          ? Container(
              width: size,
              height: size,
              color: KliqColors.surfaceElevated,
              child: Icon(Icons.person,
                  size: size * 0.6, color: KliqColors.textMuted),
            )
          : CachedNetworkImage(
              imageUrl: Api.instance.mediaUrl(url!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (c, s) =>
                  Container(color: KliqColors.surfaceElevated),
              errorWidget: (c, s, e) => Container(
                color: KliqColors.surfaceElevated,
                child: Icon(Icons.person,
                    size: size * 0.6, color: KliqColors.textMuted),
              ),
            ),
    );

    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ringSeen ? null : KliqColors.storyRing,
          border: ringSeen
              ? Border.all(color: KliqColors.border, width: 2)
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: KliqColors.background,
          ),
          child: avatar,
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../feed_models.dart';
import 'kliq_avatar.dart';

/// Horizontal story strip: "Your story" first, then avatar rings
/// (gradient ring = unseen, muted ring = seen).
class StoryBar extends StatelessWidget {
  const StoryBar({
    super.key,
    required this.groups,
    this.myAvatarUrl,
    this.onCreateStory,
  });

  final List<StoryGroup> groups;
  final String? myAvatarUrl;
  final VoidCallback? onCreateStory;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          _StoryEntry(
            label: 'Your story',
            onTap: onCreateStory,
            child: Stack(
              children: [
                KliqAvatar(url: myAvatarUrl, size: 62),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: KliqColors.storyRing,
                      shape: BoxShape.circle,
                      border: Border.all(color: KliqColors.background, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          for (final g in groups)
            _StoryEntry(
              label: g.author.username,
              onTap: () => context.push('/story/${g.userId}'),
              child: KliqAvatar(
                url: g.author.avatarUrl,
                size: 54,
                ring: true,
                ringSeen: g.seen,
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryEntry extends StatelessWidget {
  const _StoryEntry({required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            SizedBox(height: 64, width: 64, child: Center(child: child)),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: KliqColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

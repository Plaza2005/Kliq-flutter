import 'package:flutter/material.dart';

import '../../core/theme.dart';

class LiveChatMessage {
  LiveChatMessage({required this.username, required this.body, this.isGift = false});
  final String username;
  final String body;
  final bool isGift;
}

const giftCatalog = <String, ({int coins, IconData icon, Color color})>{
  'rose': (coins: 1, icon: Icons.local_florist, color: Colors.pinkAccent),
  'heart': (coins: 5, icon: Icons.favorite, color: KliqColors.live),
  'star': (coins: 10, icon: Icons.star, color: KliqColors.warning),
  'diamond': (coins: 50, icon: Icons.diamond, color: KliqColors.cyan),
  'crown': (coins: 100, icon: Icons.emoji_events, color: Colors.amber),
  'rocket': (coins: 200, icon: Icons.rocket_launch, color: KliqColors.purple),
};

/// Scrolling chat feed rendered over the video (bottom-left).
class LiveChatFeed extends StatelessWidget {
  const LiveChatFeed({super.key, required this.messages});

  final List<LiveChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
        stops: [0, 0.15],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        reverse: true,
        padding: EdgeInsets.zero,
        itemCount: messages.length,
        itemBuilder: (context, i) {
          final m = messages[messages.length - 1 - i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: m.isGift
                          ? KliqColors.pink.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${m.username}  ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: KliqColors.cyan),
                        ),
                        TextSpan(
                            text: m.body,
                            style: const TextStyle(fontSize: 12.5)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// LIVE badge + viewer count pill.
class LiveBadgeRow extends StatelessWidget {
  const LiveBadgeRow({super.key, required this.viewerCount});

  final int viewerCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: KliqColors.live,
              borderRadius: BorderRadius.circular(4)),
          child: const Text('LIVE',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4)),
          child: Row(
            children: [
              const Icon(Icons.visibility, size: 12),
              const SizedBox(width: 4),
              Text('$viewerCount',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for choosing a gift; returns the chosen gift key.
Future<String?> showGiftSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: KliqColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Send a gift',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in giftCatalog.entries)
                GestureDetector(
                  onTap: () => Navigator.pop(context, e.key),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KliqColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(e.value.icon, color: e.value.color, size: 28),
                        const SizedBox(height: 6),
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Text('${e.value.coins} tokens',
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: KliqColors.textMuted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Floating gift animation shown when someone sends a gift.
class GiftBurst extends StatelessWidget {
  const GiftBurst({super.key, required this.gift, required this.from});

  final String gift;
  final String from;

  @override
  Widget build(BuildContext context) {
    final info = giftCatalog[gift];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1600),
      builder: (context, t, child) => Opacity(
        opacity: t < 0.8 ? 1 : (1 - (t - 0.8) / 0.2),
        child: Transform.translate(
            offset: Offset(0, -60 * t), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: KliqColors.gradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info?.icon ?? Icons.card_giftcard,
                size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text('$from sent a $gift!',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

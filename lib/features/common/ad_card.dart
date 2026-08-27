import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Sponsored Ad Card widget that fills the full space of a Reel or Feed Post Card.
class FullAdCard extends StatelessWidget {
  const FullAdCard({
    super.key,
    required this.isReel,
    this.sponsorName = 'KLIQ Sponsored',
    this.headline = 'Discover Incredible Experiences with KLIQ Premium',
    this.ctaText = 'Learn More',
    this.imageUrl = 'https://picsum.photos/800/1200',
  });

  final bool isReel;
  final String sponsorName;
  final String headline;
  final String ctaText;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (isReel) {
      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: KliqColors.surfaceElevated,
                child: const Center(
                  child: Icon(Icons.campaign, size: 64, color: KliqColors.cyan),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 280,
              child: DecoratedBox(
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
            ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'AdMob Sponsored',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sponsorName,
                    style: const TextStyle(
                      color: KliqColors.cyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KliqColors.cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening sponsored ad...')),
                        );
                      },
                      child: Text(
                        ctaText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Full post space ad card in Feed
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: KliqColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KliqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: KliqColors.surfaceElevated,
              child: Icon(Icons.campaign, color: KliqColors.cyan),
            ),
            title: Text(
              sponsorName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Sponsored Ad • Google AdMob',
              style: TextStyle(color: KliqColors.textMuted, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AD',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                color: KliqColors.surfaceElevated,
                child: const Icon(Icons.campaign, size: 48, color: KliqColors.textMuted),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KliqColors.cyan,
                      side: const BorderSide(color: KliqColors.cyan),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening sponsored ad...')),
                      );
                    },
                    child: Text(ctaText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

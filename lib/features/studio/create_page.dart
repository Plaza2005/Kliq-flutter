import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'studio_common.dart';

/// The Create tab (center of the bottom bar): quick access to every
/// creation flow (Post, Reel, Story) plus Go Live.
class CreatePage extends StatelessWidget {
  const CreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Direct Go Live action — straight to the broadcaster.
          Material(
            color: KliqColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/go-live'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: KliqColors.live.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.sensors, color: KliqColors.live, size: 28),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Go Live',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          Text('Start streaming to your audience now',
                              style: TextStyle(
                                  color: KliqColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: KliqColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Quick create',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              for (final m in studioModules)
                Material(
                  color: KliqColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push(m.route),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: KliqColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(m.icon, color: m.color, size: 26),
                          const SizedBox(height: 8),
                          Text(m.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

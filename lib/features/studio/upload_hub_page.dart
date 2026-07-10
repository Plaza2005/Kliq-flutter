import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'studio_common.dart';

/// Upload Hub — opened by the Upload button in Studio.
///
/// PRODUCT RULE: this page never uploads anything itself. It lists every
/// part of the app you can publish to (Posts, Reels, KliqTube, Stories,
/// Live, Marketplace, KliqStream) and each tile NAVIGATES to that module's
/// own independent studio page — e.g. tapping KliqTube opens KliqTube
/// Studio, where the actual video upload happens.
class UploadHubPage extends StatelessWidget {
  const UploadHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Where do you want to publish?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Each destination has its own studio with tools made for that '
            'format.',
            style: TextStyle(color: KliqColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          for (final m in studioModules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModuleTile(module: m),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final StudioModule module;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: KliqColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Navigate to the module's own studio page — never upload in place.
        onTap: () => context.push(module.route),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KliqColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(module.icon, color: module.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${module.label} Studio',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(module.description,
                        style: const TextStyle(
                            color: KliqColors.textSecondary,
                            fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KliqColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

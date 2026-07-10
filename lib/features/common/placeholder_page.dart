import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Temporary stand-in used while feature pages are under construction.
/// Every route in the router resolves to a real page or one of these, so
/// navigation never dead-ends.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => KliqColors.gradient.createShader(b),
              child: const Icon(Icons.auto_awesome, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: const TextStyle(color: KliqColors.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

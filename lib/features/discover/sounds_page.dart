import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'discover_common.dart';

/// Browsable sounds/audio library (reference: prot_3 SoundsPage.tsx).
class SoundsPage extends StatelessWidget {
  const SoundsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sounds')),
      body: FutureBuilder(
        future: Api.instance.get('/sounds').catchError((_) => []),
        builder: (context, snap) {
          if (!snap.hasData) return const CenterSpinner();
          final sounds = asMapList(snap.data, key: 'sounds');
          if (sounds.isEmpty) {
            return const EmptyState(
                icon: Icons.music_note_outlined,
                title: 'No sounds yet',
                subtitle: 'Trending audio will appear here');
          }
          return ListView.builder(
            itemCount: sounds.length,
            itemBuilder: (context, i) {
              final s = sounds[i];
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: KliqColors.gradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
                title: Text(pickStr(s, ['name', 'title'])),
                subtitle: Text(
                  '${pickStr(s, ['artist'], fallback: 'Original audio')} · '
                  '${fmtCount(pickInt(s, ['useCount']))} reels',
                  style: const TextStyle(
                      color: KliqColors.textMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.play_circle_outline,
                    color: KliqColors.cyan),
              );
            },
          );
        },
      ),
    );
  }
}

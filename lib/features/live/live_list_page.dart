import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';
import 'live_widgets.dart';

/// Full page at `/live`: the live-streams grid with an app bar + Go Live.
class LiveListPage extends StatelessWidget {
  const LiveListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Now',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/go-live'),
            icon: const Icon(Icons.sensors, color: KliqColors.live),
            label: const Text('Go Live',
                style: TextStyle(
                    color: KliqColors.live, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: const LiveStreamsView(),
    );
  }
}

/// Reusable grid of everyone currently live. Used by [LiveListPage] and by the
/// Reels page's "Live" tab.
class LiveStreamsView extends StatefulWidget {
  const LiveStreamsView({super.key});

  @override
  State<LiveStreamsView> createState() => _LiveStreamsViewState();
}

class _LiveStreamsViewState extends State<LiveStreamsView> {
  List<Map<String, dynamic>> _streams = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/live/streams');
      if (!mounted) return;
      setState(() {
        _streams = asMapList(data, key: 'streams');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
          ? const CenterSpinner()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _streams.isEmpty
                  ? EmptyState(
                      icon: Icons.sensors_off,
                      title: 'No one is live right now',
                      subtitle: 'Start your own stream and be first!',
                      actionLabel: 'Go Live',
                      onAction: () => context.push('/go-live'))
                  : RefreshIndicator(
                      color: KliqColors.cyan,
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          childAspectRatio: 16 / 12,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: _streams.length,
                        itemBuilder: (context, i) {
                          final s = _streams[i];
                          final host = authorOf(s);
                          return GestureDetector(
                            onTap: () =>
                                context.push('/live/${s['id']}'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  NetImg(pickStr(s, ['thumbnailUrl'])),
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: LiveBadgeRow(
                                        viewerCount: pickInt(
                                            s, ['viewerCount'])),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding:
                                          const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.black
                                                .withValues(alpha: 0.85)
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          KliqAvatar(host['avatarUrl'],
                                              radius: 13),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Text(
                                                    pickStr(
                                                        s, ['title']),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight
                                                                .w700,
                                                        fontSize:
                                                            12.5)),
                                                Text(
                                                    host['displayName'] ??
                                                        '',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    style: const TextStyle(
                                                        color: KliqColors
                                                            .textSecondary,
                                                        fontSize: 11)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
  }
}

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// Amplify (paid content boosting) and creator Analytics.

class AmplifyPage extends StatefulWidget {
  const AmplifyPage({super.key});

  @override
  State<AmplifyPage> createState() => _AmplifyPageState();
}

class _AmplifyPageState extends State<AmplifyPage> {
  double _budget = 100;
  double _days = 3;
  List<Map<String, dynamic>> _campaigns = [];
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/amplify/campaigns');
      if (mounted) {
        setState(
            () => _campaigns = asMapList(data, key: 'campaigns'));
      }
    } catch (_) {}
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/amplify/campaigns', body: {
        'budget': _budget.round(),
        'days': _days.round(),
      });
      messenger.showSnackBar(const SnackBar(
          content: Text('Amplify campaign started 🚀')));
      _load();
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not start: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reach = (_budget * 42 * _days / 3).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amplify',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: KliqColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KliqColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Boost your content',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  'Surface your content beyond your followers with granular '
                  'budget and duration controls.',
                  style: TextStyle(
                      color: KliqColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Text('Budget — N\$${_budget.round()}',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _budget,
                  min: 20,
                  max: 1000,
                  divisions: 49,
                  activeColor: KliqColors.cyan,
                  onChanged: (v) => setState(() => _budget = v),
                ),
                Text('Duration — ${_days.round()} days',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                Slider(
                  value: _days,
                  min: 1,
                  max: 14,
                  divisions: 13,
                  activeColor: KliqColors.pink,
                  onChanged: (v) => setState(() => _days = v),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KliqColors.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Estimated reach: ~${fmtCount(reach)} accounts',
                    style: const TextStyle(
                        color: KliqColors.cyan,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KliqColors.gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _creating ? null : _create,
                      child: Text(
                          _creating
                              ? 'Starting…'
                              : 'Start Campaign',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Your campaigns',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_campaigns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No campaigns yet',
                    style: TextStyle(color: KliqColors.textMuted)),
              ),
            )
          else
            for (final c in _campaigns)
              ListTile(
                leading: const Icon(Icons.rocket_launch,
                    color: KliqColors.pink),
                title: Text(
                    'N\$${pickInt(c, ['budget'])} · ${pickInt(c, ['days'])} days',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    '${fmtCount(pickInt(c, ['reached']))} reached · ${pickStr(c, ['status'], fallback: 'active')}',
                    style: const TextStyle(
                        color: KliqColors.textMuted, fontSize: 12)),
              ),
        ],
      ),
    );
  }
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String _range = '7D';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance
          .get('/analytics/overview', query: {'range': _range});
      if (mounted) {
        setState(() {
          _data = asMap(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = asMapList(_data['series'], key: 'series');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          for (final r in const ['7D', '30D', '90D'])
            TextButton(
              onPressed: () {
                setState(() {
                  _range = r;
                  _loading = true;
                });
                _load();
              },
              child: Text(r,
                  style: TextStyle(
                      color: _range == r
                          ? KliqColors.cyan
                          : KliqColors.textMuted,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const CenterSpinner()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    _statCard('Views',
                        fmtCount(pickInt(_data, ['views'])), Icons.visibility),
                    _statCard(
                        'Followers',
                        '+${fmtCount(pickInt(_data, ['newFollowers']))}',
                        Icons.person_add),
                    _statCard('Likes',
                        fmtCount(pickInt(_data, ['likes'])), Icons.favorite),
                    _statCard(
                        'Revenue',
                        'N\$${pickInt(_data, ['revenue'])}',
                        Icons.payments),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Views over time',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  height: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KliqColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KliqColors.border),
                  ),
                  child: series.isEmpty
                      ? const Center(
                          child: Text('No data yet',
                              style: TextStyle(
                                  color: KliqColors.textMuted)))
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final point in series)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: FractionallySizedBox(
                                          alignment:
                                              Alignment.bottomCenter,
                                          heightFactor: (pickInt(
                                                      point, ['value']) /
                                                  _maxSeries(series))
                                              .clamp(0.03, 1.0),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient:
                                                  KliqColors.gradient,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      3),
                                            ),
                                            child: const SizedBox
                                                .expand(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                          pickStr(point, ['label'])
                                              .split('-')
                                              .last,
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: KliqColors
                                                  .textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                const Text('Audience',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _audienceRow('Top location',
                    pickStr(_data, ['topLocation'], fallback: 'Windhoek, NA')),
                _audienceRow('Top age range',
                    pickStr(_data, ['topAge'], fallback: '18–24')),
                _audienceRow('Peak activity',
                    pickStr(_data, ['peakHours'], fallback: '19:00–22:00')),
              ],
            ),
    );
  }

  int _maxSeries(List<Map<String, dynamic>> series) {
    var max = 1;
    for (final s in series) {
      final v = pickInt(s, ['value']);
      if (v > max) max = v;
    }
    return max;
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KliqColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KliqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: KliqColors.textMuted),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: KliqColors.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _audienceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: KliqColors.textSecondary, fontSize: 13.5)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
    );
  }
}

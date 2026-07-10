import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// Wallet: balances (tokens / diamonds / cash), transactions, orders and
/// token top-up (payment).

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map<String, dynamic> _wallet = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/wallet');
      if (mounted) {
        setState(() {
          _wallet = asMap(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = asMapList(_wallet['transactions'], key: 'transactions');
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Orders',
              onPressed: () => context.push('/wallet/orders')),
        ],
      ),
      body: _loading
          ? const CenterSpinner()
          : RefreshIndicator(
              color: KliqColors.cyan,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: KliqColors.gradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Balance',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                            'N\$${(_wallet['balance'] as num? ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _chip(Icons.toll,
                                '${pickInt(_wallet, ['tokens'])} tokens'),
                            const SizedBox(width: 10),
                            _chip(Icons.diamond,
                                '${pickInt(_wallet, ['diamonds'])} diamonds'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/payment'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Buy tokens'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KliqColors.textPrimary,
                            side: const BorderSide(
                                color: KliqColors.border),
                          ),
                          onPressed: () =>
                              context.push('/wallet/history'),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('History'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Recent activity',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  if (txs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: Text('No transactions yet',
                              style: TextStyle(
                                  color: KliqColors.textMuted))),
                    )
                  else
                    for (final t in txs.take(6)) TransactionTile(tx: t),
                ],
              ),
            ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx});

  final Map<String, dynamic> tx;

  @override
  Widget build(BuildContext context) {
    final amount = (tx['amount'] as num? ?? 0).toInt();
    final positive = amount >= 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (positive ? KliqColors.success : KliqColors.danger)
            .withValues(alpha: 0.15),
        child: Icon(positive ? Icons.south_west : Icons.north_east,
            size: 18,
            color: positive ? KliqColors.success : KliqColors.danger),
      ),
      title: Text(pickStr(tx, ['description']),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(timeAgo(tx['createdAt']?.toString()),
          style:
              const TextStyle(color: KliqColors.textMuted, fontSize: 11.5)),
      trailing: Text('${positive ? '+' : ''}$amount',
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color:
                  positive ? KliqColors.success : KliqColors.danger)),
    );
  }
}

class WalletHistoryPage extends StatelessWidget {
  const WalletHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: FutureBuilder(
        future: Api.instance.get('/wallet/history').catchError((_) => []),
        builder: (context, snap) {
          if (!snap.hasData) return const CenterSpinner();
          final txs = asMapList(snap.data, key: 'transactions');
          if (txs.isEmpty) {
            return const EmptyState(
                icon: Icons.history, title: 'No transactions yet');
          }
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [for (final t in txs) TransactionTile(tx: t)],
          );
        },
      ),
    );
  }
}

class WalletOrdersPage extends StatelessWidget {
  const WalletOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: FutureBuilder(
        future: Api.instance.get('/wallet/orders').catchError((_) => []),
        builder: (context, snap) {
          if (!snap.hasData) return const CenterSpinner();
          final orders = asMapList(snap.data, key: 'orders');
          if (orders.isEmpty) {
            return const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                subtitle: 'Marketplace purchases will appear here');
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final o = orders[i];
              return ListTile(
                leading: const Icon(Icons.shopping_bag_outlined,
                    color: KliqColors.cyan),
                title: Text(pickStr(o, ['productName', 'name'])),
                subtitle: Text(
                    '${pickStr(o, ['status'], fallback: 'processing')} · ${timeAgo(o['createdAt']?.toString())}',
                    style: const TextStyle(
                        color: KliqColors.textMuted, fontSize: 12)),
                trailing: Text('N\$${o['price'] ?? o['amount'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            },
          );
        },
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  int? _selected;
  bool _busy = false;
  static const _packs = [
    (tokens: 100, price: 15),
    (tokens: 500, price: 65),
    (tokens: 1200, price: 140),
    (tokens: 3000, price: 320),
  ];

  Future<void> _buy() async {
    if (_selected == null) return;
    setState(() => _busy = true);
    final pack = _packs[_selected!];
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/wallet/purchase',
          body: {'tokens': pack.tokens, 'amount': pack.price});
      messenger.showSnackBar(SnackBar(
          content: Text('${pack.tokens} tokens added to your wallet 🎉')));
      if (mounted) context.pop();
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Tokens')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tokens power gifts, paylocked content and Amplify campaigns.',
            style: TextStyle(color: KliqColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _packs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setState(() => _selected = i),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KliqColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _selected == i
                            ? KliqColors.cyan
                            : KliqColors.border,
                        width: _selected == i ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.toll, color: KliqColors.warning),
                      const SizedBox(width: 12),
                      Text('${_packs[i].tokens} tokens',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('N\$${_packs[i].price}',
                          style: const TextStyle(
                              color: KliqColors.cyan,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: KliqColors.gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              onPressed: _selected == null || _busy ? null : _buy,
              child: Text(_busy ? 'Processing…' : 'Pay Now',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

/// Marketplace: browse, product detail (buy), seller storefront, shop
/// customisation.

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.get('/marketplace/products');
      if (!mounted) return;
      setState(() {
        _products = asMapList(data, key: 'products');
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
    final filtered = _filter == 'All'
        ? _products
        : _products
            .where((p) => pickStr(p, ['category']) == _filter)
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Orders',
              onPressed: () => context.push('/wallet/orders')),
          IconButton(
              icon: const Icon(Icons.add_business_outlined),
              tooltip: 'Sell',
              onPressed: () => context.push('/studio/marketplace')),
        ],
      ),
      body: _loading
          ? const CenterSpinner()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final f in const [
                            'All',
                            'Physical',
                            'Digital'
                          ])
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: 8, top: 8, bottom: 8),
                              child: ChoiceChip(
                                label: Text(f),
                                selected: _filter == f,
                                selectedColor: KliqColors.cyan
                                    .withValues(alpha: 0.3),
                                onSelected: (_) =>
                                    setState(() => _filter = f),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const EmptyState(
                              icon: Icons.storefront_outlined,
                              title: 'No products yet')
                          : RefreshIndicator(
                              color: KliqColors.cyan,
                              onRefresh: _load,
                              child: GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 240,
                                  childAspectRatio: 0.72,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, i) =>
                                    _ProductCard(product: filtered[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final img = product['imageUrls'] is List &&
            (product['imageUrls'] as List).isNotEmpty
        ? (product['imageUrls'] as List).first.toString()
        : null;
    return GestureDetector(
      onTap: () => context.push('/marketplace/product/${product['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: KliqColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KliqColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SizedBox(width: double.infinity, child: NetImg(img))),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pickStr(product, ['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                      'N\$${product['price']}',
                      style: const TextStyle(
                          color: KliqColors.cyan,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Map<String, dynamic>? _product;
  bool _loading = true;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await Api.instance.get('/marketplace/${widget.productId}');
      if (mounted) {
        setState(() {
          _product = asMap(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buy() async {
    setState(() => _buying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance
          .post('/marketplace/${widget.productId}/buy');
      messenger.showSnackBar(const SnackBar(
          content: Text('Order placed! Check Wallet → Orders.')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    final p = _product ?? {};
    final seller = authorOf(p);
    final img = p['imageUrls'] is List && (p['imageUrls'] as List).isNotEmpty
        ? (p['imageUrls'] as List).first.toString()
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: ListView(
        children: [
          AspectRatio(aspectRatio: 1, child: NetImg(img)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pickStr(p, ['name']),
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('N\$${p['price']}',
                        style: const TextStyle(
                            color: KliqColors.cyan,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    const Icon(Icons.star,
                        size: 15, color: KliqColors.warning),
                    const SizedBox(width: 4),
                    Text(
                        '${(p['rating'] as num? ?? 0).toStringAsFixed(1)} · '
                        '${pickInt(p, ['salesCount'])} sold',
                        style: const TextStyle(
                            color: KliqColors.textMuted, fontSize: 12.5)),
                  ],
                ),
                const Divider(height: 28),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: KliqAvatar(seller['avatarUrl']),
                  title: Text(seller['displayName'] ?? 'Seller',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('View storefront',
                      style: TextStyle(
                          color: KliqColors.textMuted, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: KliqColors.textMuted),
                  onTap: () {
                    final sellerMap = asMap(p['seller']);
                    context.push(
                        '/marketplace/seller/${sellerMap['id'] ?? ''}');
                  },
                ),
                const SizedBox(height: 8),
                Text(pickStr(p, ['description']),
                    style: const TextStyle(
                        color: KliqColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.5)),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KliqColors.gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: _buying ? null : _buy,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(_buying ? 'Placing order…' : 'Buy Now',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800)),
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
}

class SellerPage extends StatefulWidget {
  const SellerPage({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  Map<String, dynamic>? _seller;
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final seller = await Api.instance.get('/users/${widget.sellerId}');
      final all = await Api.instance.get('/marketplace/products');
      if (!mounted) return;
      setState(() {
        _seller = asMap(seller);
        _products = asMapList(all, key: 'products').where((p) {
          final s = asMap(p['seller']);
          return s['id']?.toString() == widget.sellerId;
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const CenterSpinner());
    }
    final u = _seller ?? {};
    return Scaffold(
      appBar: AppBar(
          title: Text(pickStr(u, ['displayName'], fallback: 'Storefront'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            leading: KliqAvatar(u['avatarUrl']?.toString(), radius: 26),
            title: Text(pickStr(u, ['displayName', 'username']),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            subtitle: Text(
                '@${pickStr(u, ['username'])} · ${_products.length} products',
                style: const TextStyle(color: KliqColors.textMuted)),
            onTap: () => context.push('/user/${pickStr(u, ['username'])}'),
          ),
          const SizedBox(height: 8),
          if (_products.isEmpty)
            const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'No products listed')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                childAspectRatio: 0.72,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _products.length,
              itemBuilder: (context, i) =>
                  _ProductCard(product: _products[i]),
            ),
        ],
      ),
    );
  }
}

class CustomizeShopPage extends StatefulWidget {
  const CustomizeShopPage({super.key});

  @override
  State<CustomizeShopPage> createState() => _CustomizeShopPageState();
}

class _CustomizeShopPageState extends State<CustomizeShopPage> {
  final _shopName = TextEditingController();
  final _tagline = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/marketplace/shop', body: {
        'name': _shopName.text.trim(),
        'tagline': _tagline.text.trim(),
      });
      messenger
          .showSnackBar(const SnackBar(content: Text('Shop updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customize Shop')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _shopName,
              decoration: const InputDecoration(hintText: 'Shop name')),
          const SizedBox(height: 12),
          TextField(
              controller: _tagline,
              decoration: const InputDecoration(hintText: 'Tagline')),
          const SizedBox(height: 18),
          ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save')),
        ],
      ),
    );
  }
}

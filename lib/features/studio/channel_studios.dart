import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';
import 'module_studios.dart';
import 'studio_common.dart';

/// Independent studios for the channel-like modules: KliqTube (channel
/// manager + video upload), Marketplace (product manager) and KliqStream
/// (originals submissions).

// ── KliqTube Studio ────────────────────────────────────────────────────────

class KliqTubeStudioPage extends StatefulWidget {
  const KliqTubeStudioPage({super.key});

  @override
  State<KliqTubeStudioPage> createState() => _KliqTubeStudioPageState();
}

class _KliqTubeStudioPageState extends State<KliqTubeStudioPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  String? _videoUrl;
  String? _thumbUrl;
  bool _videoBusy = false;
  bool _thumbBusy = false;
  bool _publishing = false;
  String _category = 'Entertainment';
  String _visibility = 'public';
  List<Map<String, dynamic>> _myVideos = [];

  static const _categories = [
    'Entertainment', 'Music', 'Education', 'Gaming', 'Sports',
    'Food', 'Travel', 'Tech', 'Documentary', 'Comedy',
  ];

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    try {
      final me = context.read<Session>().userId;
      final all = await Api.instance.get('/kliqtube');
      if (!mounted) return;
      setState(() {
        _myVideos = asMapList(all, key: 'videos').where((v) {
          final a = asMap(v['author'] ?? v['user']);
          return a['id']?.toString() == me;
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty || _videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A title and a video are required')));
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/kliqtube', body: {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'videoUrl': _videoUrl,
        'thumbnailUrl': _thumbUrl,
        'category': _category,
        'visibility': _visibility,
        'tags': _tags.text
            .split(',')
            .map((t) => t.trim().replaceFirst('#', ''))
            .where((t) => t.isNotEmpty)
            .toList(),
      });
      messenger.showSnackBar(SnackBar(
          content: Text(_visibility == 'public'
              ? 'Video published to KliqTube 📺'
              : 'Video uploaded as $_visibility 📺')));
      _title.clear();
      _description.clear();
      _tags.clear();
      setState(() {
        _videoUrl = null;
        _thumbUrl = null;
        _publishing = false;
      });
      _loadMine();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Publish failed: $e')));
      setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioModuleScaffold(
      module: studioModules[2],
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MediaSlot(
            label: 'Pick your video file',
            icon: Icons.video_file_outlined,
            url: _videoUrl,
            busy: _videoBusy,
            onPick: () async {
              setState(() => _videoBusy = true);
              final url = await pickAndUploadVideo(context);
              if (mounted) {
                setState(() {
                  if (url != null) _videoUrl = url;
                  _videoBusy = false;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          MediaSlot(
            label: 'Thumbnail (optional)',
            icon: Icons.image_outlined,
            url: _thumbUrl,
            busy: _thumbBusy,
            onPick: () async {
              setState(() => _thumbBusy = true);
              final url = await pickAndUploadImage(context);
              if (mounted) {
                setState(() {
                  if (url != null) _thumbUrl = url;
                  _thumbBusy = false;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'Video title')),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Description, chapters, links…'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              hintText: 'Tags, comma separated (music, tutorial, namibia)',
              prefixIcon:
                  Icon(Icons.tag, size: 18, color: KliqColors.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Category',
              style: TextStyle(
                  fontSize: 12.5, color: KliqColors.textSecondary)),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label:
                          Text(c, style: const TextStyle(fontSize: 12)),
                      selected: _category == c,
                      selectedColor:
                          KliqColors.cyan.withValues(alpha: 0.3),
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Visibility',
              style: TextStyle(
                  fontSize: 12.5, color: KliqColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final v in const [
                ('public', Icons.public, 'Public'),
                ('unlisted', Icons.link, 'Unlisted'),
                ('private', Icons.lock_outline, 'Private'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(v.$2,
                        size: 14,
                        color: _visibility == v.$1
                            ? KliqColors.cyan
                            : KliqColors.textMuted),
                    label:
                        Text(v.$3, style: const TextStyle(fontSize: 12)),
                    selected: _visibility == v.$1,
                    selectedColor:
                        KliqColors.cyan.withValues(alpha: 0.25),
                    onSelected: (_) =>
                        setState(() => _visibility = v.$1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          PublishButton(
              label: 'Publish to KliqTube',
              busy: _publishing,
              onTap: _publish),
        ],
      ),
      contentList: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your channel',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_myVideos.isEmpty)
            const Text('No uploads yet — your videos will appear here.',
                style:
                    TextStyle(color: KliqColors.textMuted, fontSize: 13))
          else
            for (final v in _myVideos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                      width: 88,
                      height: 50,
                      child: NetImg(pickStr(v, ['thumbnailUrl']))),
                ),
                title: Text(pickStr(v, ['title']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                    '${fmtCount(pickInt(v, ['viewCount']))} views',
                    style: const TextStyle(
                        color: KliqColors.textMuted, fontSize: 12)),
              ),
        ],
      ),
    );
  }
}

// ── Marketplace Studio ─────────────────────────────────────────────────────

class MarketplaceStudioPage extends StatefulWidget {
  const MarketplaceStudioPage({super.key});

  @override
  State<MarketplaceStudioPage> createState() => _MarketplaceStudioPageState();
}

class _MarketplaceStudioPageState extends State<MarketplaceStudioPage> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _stock = TextEditingController(text: '1');
  final _delivery = TextEditingController();
  final _imageUrls = <String>[];
  bool _imageBusy = false;
  bool _publishing = false;
  String _category = 'Physical';

  static const _maxPhotos = 6;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _stock.dispose();
    _delivery.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_imageUrls.length >= _maxPhotos) return;
    setState(() => _imageBusy = true);
    final url = await pickAndUploadImage(context);
    if (mounted) {
      setState(() {
        if (url != null) _imageUrls.add(url);
        _imageBusy = false;
      });
    }
  }

  Future<void> _publish() async {
    final price = double.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A product name and valid price are required')));
      return;
    }
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one product photo')));
      return;
    }
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/marketplace/products', body: {
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'price': price,
        'category': _category,
        'imageUrls': _imageUrls,
        'stock': int.tryParse(_stock.text.trim()) ?? 1,
        if (_delivery.text.trim().isNotEmpty)
          'deliveryInfo': _delivery.text.trim(),
      });
      messenger.showSnackBar(
          const SnackBar(content: Text('Product listed on Marketplace 🛍️')));
      _name.clear();
      _price.clear();
      _description.clear();
      _delivery.clear();
      _stock.text = '1';
      setState(() {
        _imageUrls.clear();
        _publishing = false;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Listing failed: $e')));
      setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioModuleScaffold(
      module: studioModules[5],
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Photos (${_imageUrls.length}/$_maxPhotos) — first photo is the '
            'cover',
            style: const TextStyle(
                color: KliqColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _imageUrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MediaThumb(
                      url: _imageUrls[i],
                      onRemove: () =>
                          setState(() => _imageUrls.removeAt(i)),
                    ),
                  ),
                if (_imageUrls.length < _maxPhotos)
                  AddMediaTile(busy: _imageBusy, onTap: _addPhoto),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _name,
              decoration: const InputDecoration(hintText: 'Product name')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(hintText: 'Price (N\$)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'Stock'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration:
                const InputDecoration(hintText: 'Describe your product…'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _delivery,
            decoration: const InputDecoration(
              hintText: 'Delivery / collection info (optional)',
              prefixIcon: Icon(Icons.local_shipping_outlined,
                  size: 18, color: KliqColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in const ['Physical', 'Digital'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    selectedColor: KliqColors.cyan.withValues(alpha: 0.3),
                    onSelected: (_) => setState(() => _category = c),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          PublishButton(
              label: 'List Product', busy: _publishing, onTap: _publish),
        ],
      ),
    );
  }
}

// ── KliqStream Studio ──────────────────────────────────────────────────────

class KliqStreamStudioPage extends StatefulWidget {
  const KliqStreamStudioPage({super.key});

  @override
  State<KliqStreamStudioPage> createState() => _KliqStreamStudioPageState();
}

class _KliqStreamStudioPageState extends State<KliqStreamStudioPage> {
  final _title = TextEditingController();
  final _pitch = TextEditingController();
  String? _videoUrl;
  bool _videoBusy = false;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A title and a pilot episode are required')));
      return;
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.instance.post('/kliqstream/submissions', body: {
        'title': _title.text.trim(),
        'pitch': _pitch.text.trim(),
        'videoUrl': _videoUrl,
      });
      messenger.showSnackBar(const SnackBar(
          content:
              Text('Submitted! The KliqStream team will review your show.')));
      _title.clear();
      _pitch.clear();
      setState(() {
        _videoUrl = null;
        _submitting = false;
      });
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudioModuleScaffold(
      module: studioModules[6],
      composer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pitch an original show for the KliqStream catalogue. Upload a '
            'pilot episode; approved shows get a full series page.',
            style: TextStyle(color: KliqColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          MediaSlot(
            label: 'Upload pilot episode',
            icon: Icons.theaters_outlined,
            url: _videoUrl,
            busy: _videoBusy,
            onPick: () async {
              setState(() => _videoBusy = true);
              final url = await pickAndUploadVideo(context);
              if (mounted) {
                setState(() {
                  if (url != null) _videoUrl = url;
                  _videoBusy = false;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'Show title')),
          const SizedBox(height: 10),
          TextField(
            controller: _pitch,
            maxLines: 4,
            decoration: const InputDecoration(
                hintText: 'What is your show about? Who is it for?'),
          ),
          const SizedBox(height: 14),
          PublishButton(
              label: 'Submit for Review', busy: _submitting, onTap: _submit),
        ],
      ),
    );
  }
}

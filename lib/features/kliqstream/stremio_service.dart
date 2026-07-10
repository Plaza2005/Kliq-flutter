import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client for the Stremio add-on protocol (stremio-addon-sdk).
///
/// Every add-on is a static HTTP API:
///   {base}/manifest.json
///   {base}/catalog/{type}/{id}.json            (+ /search={q}.json extra)
///   {base}/meta/{type}/{id}.json               (series meta carries episodes)
///   {base}/stream/{type}/{id}.json             ({streams:[{url,...}]})
///
/// Cinemeta (Stremio's official metadata add-on) is bundled as the default
/// source for movie/series catalogues, search and metadata. Users can add
/// further add-on URLs (e.g. their own stremio-addon-sdk deployment) in the
/// KliqStream add-on manager; any add-on that answers `stream` requests
/// with a direct http(s) url becomes playable inside KliqStream.
class StremioClient {
  StremioClient._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
    ));
  }

  static final instance = StremioClient._();
  late final Dio _dio;

  static const cinemeta = 'https://v3-cinemeta.strem.io';
  static const _prefsKey = 'kliq.stremio.addons';

  List<String> _addons = [cinemeta];
  List<String> get addons => List.unmodifiable(_addons);

  final _manifests = <String, Map<String, dynamic>>{};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey);
    if (stored != null && stored.isNotEmpty) {
      _addons = stored;
    }
    if (!_addons.contains(cinemeta)) _addons.insert(0, cinemeta);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _addons);
  }

  /// Normalises an add-on URL ("...manifest.json" or bare base) to its base.
  static String normalize(String url) {
    var u = url.trim();
    if (u.endsWith('/manifest.json')) {
      u = u.substring(0, u.length - '/manifest.json'.length);
    }
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  /// Validates and registers an add-on; returns its manifest name.
  Future<String> addAddon(String url) async {
    final base = normalize(url);
    final manifest = await getManifest(base);
    if (!_addons.contains(base)) {
      _addons.add(base);
      await _persist();
    }
    return manifest['name']?.toString() ?? base;
  }

  Future<void> removeAddon(String base) async {
    if (base == cinemeta) return; // keep the default metadata source
    _addons.remove(base);
    await _persist();
  }

  Future<Map<String, dynamic>> getManifest(String base) async {
    if (_manifests.containsKey(base)) return _manifests[base]!;
    final res = await _dio.get('$base/manifest.json');
    final manifest = _asMap(res.data);
    if (manifest['id'] == null) {
      throw Exception('Not a Stremio add-on (no manifest id)');
    }
    _manifests[base] = manifest;
    return manifest;
  }

  /// Catalog request. [catalogId] examples for Cinemeta: `top`, `year`,
  /// `imdbRating`. Pass [search] for the search extra.
  Future<List<Map<String, dynamic>>> catalog(
    String type,
    String catalogId, {
    String? search,
    int skip = 0,
    String base = cinemeta,
  }) async {
    final extra = search != null && search.isNotEmpty
        ? '/search=${Uri.encodeComponent(search)}'
        : (skip > 0 ? '/skip=$skip' : '');
    final res =
        await _dio.get('$base/catalog/$type/$catalogId$extra.json');
    final metas = _asMap(res.data)['metas'];
    return metas is List
        ? metas.whereType<Map>().map((e) => _asMap(e)).toList()
        : <Map<String, dynamic>>[];
  }

  /// Full metadata (for series includes `videos` = episode list).
  Future<Map<String, dynamic>> meta(String type, String id,
      {String base = cinemeta}) async {
    final res = await _dio.get('$base/meta/$type/$id.json');
    return _asMap(_asMap(res.data)['meta']);
  }

  /// Searches movies + series across the default catalogue.
  Future<List<Map<String, dynamic>>> search(String query) async {
    final results = await Future.wait([
      catalog('movie', 'top', search: query).catchError((_) => <Map<String, dynamic>>[]),
      catalog('series', 'top', search: query).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    return [...results[0], ...results[1]];
  }

  /// Asks every registered add-on that serves `stream` resources for
  /// streams of [id] (e.g. `tt0111161` or `tt0903747:1:1` for S01E01).
  /// Only direct http(s) URLs are returned — playable by media_kit.
  Future<List<Map<String, dynamic>>> streams(String type, String id) async {
    final playable = <Map<String, dynamic>>[];
    for (final base in _addons) {
      try {
        final manifest = await getManifest(base);
        final resources = (manifest['resources'] as List? ?? [])
            .map((r) => r is Map ? r['name']?.toString() : r?.toString())
            .toList();
        if (!resources.contains('stream')) continue;
        final res = await _dio.get('$base/stream/$type/$id.json');
        final streams = _asMap(res.data)['streams'];
        if (streams is List) {
          for (final s in streams.whereType<Map>()) {
            final url = s['url']?.toString() ?? '';
            if (url.startsWith('http')) {
              playable.add({
                ..._asMap(s),
                'addonName': manifest['name'] ?? base,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[stremio] $base stream lookup failed: $e');
      }
    }
    return playable;
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}

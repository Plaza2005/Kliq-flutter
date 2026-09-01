/// Helper class to resolve and merge Cloudflare object URLs (from R2, Cloudflare Stream,
/// or Cloudflare Images) with Supabase database metadata when content is requested.
class MediaResolver {
  MediaResolver._();

  static const String _cloudflareCdnDomain = 'https://cdn.kliq.app';

  /// Merges object keys / raw media values stored in metadata into fully qualified Cloudflare CDN URLs.
  static String resolveUrl(String? rawUrlOrKey) {
    if (rawUrlOrKey == null || rawUrlOrKey.trim().isEmpty) {
      return '';
    }
    final input = rawUrlOrKey.trim();
    if (input.startsWith('http://') || input.startsWith('https://')) {
      return input;
    }
    // If input is a Cloudflare object key (e.g. "uploads/videos/reel_123.mp4"), prepend CDN domain
    final cleanKey = input.startsWith('/') ? input.substring(1) : input;
    return '$_cloudflareCdnDomain/$cleanKey';
  }

  /// Merges a raw metadata payload from Supabase with object URLs from Cloudflare.
  static Map<String, dynamic> mergeMetadataAndObjects(Map<String, dynamic> metadata) {
    final copy = Map<String, dynamic>.from(metadata);

    if (copy.containsKey('videoUrl')) {
      copy['videoUrl'] = resolveUrl(copy['videoUrl']?.toString());
    }
    if (copy.containsKey('mediaUrl')) {
      copy['mediaUrl'] = resolveUrl(copy['mediaUrl']?.toString());
    }
    if (copy.containsKey('thumbnailUrl')) {
      copy['thumbnailUrl'] = resolveUrl(copy['thumbnailUrl']?.toString());
    }

    if (copy['mediaUrls'] is List) {
      final list = (copy['mediaUrls'] as List)
          .map((e) => resolveUrl(e?.toString()))
          .toList();
      copy['mediaUrls'] = list;
    }

    if (copy['author'] is Map) {
      final author = Map<String, dynamic>.from(copy['author'] as Map);
      if (author.containsKey('avatarUrl')) {
        author['avatarUrl'] = resolveUrl(author['avatarUrl']?.toString());
      }
      copy['author'] = author;
    }

    return copy;
  }
}

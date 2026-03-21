import 'package:flutter/foundation.dart' show kIsWeb;

class Artwork {
  final int id;
  final String title;
  final String artist;
  final String date;
  final String? description;
  final String? medium;
  final String? dimensions;
  final String? creditLine;
  final String? placeOfOrigin;
  final String? department;
  final String? artistBio;
  final List<String> tags;

  // API固有の画像情報（内部使用）
  final String? _imageUrl;
  final String? _imageUrlHigh;

  Artwork({
    required this.id,
    required this.title,
    required this.artist,
    required this.date,
    this.description,
    this.medium,
    this.dimensions,
    this.creditLine,
    this.placeOfOrigin,
    this.department,
    this.artistBio,
    this.tags = const [],
    String? imageUrl,
    String? imageUrlHigh,
  })  : _imageUrl = imageUrl,
        _imageUrlHigh = imageUrlHigh;

  /// 画像URL（Web時のCORSプロキシ対応込み）
  String? get imageUrl => _imageUrl;

  /// 高解像度画像URL
  String? get imageUrlHigh => _imageUrlHigh;

  // ---------------------------------------------------------------------------
  // Met Museum API
  // ---------------------------------------------------------------------------
  factory Artwork.fromMetJson(Map<String, dynamic> json) {
    final tagList = <String>[];
    final rawTags = json['tags'];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag is Map && tag['term'] != null) {
          tagList.add(tag['term'] as String);
        }
      }
    }

    final artistBio = json['artistDisplayBio'] as String?;
    final medium = json['medium'] as String?;
    final classification = json['classification'] as String?;
    final culture = json['culture'] as String?;
    final period = json['period'] as String?;

    final desc = _buildMetDescription(
      artist: json['artistDisplayName'] as String? ?? '',
      artistBio: artistBio,
      medium: medium,
      classification: classification,
      culture: culture,
      period: period,
      tags: tagList,
    );

    final smallImg = json['primaryImageSmall'] as String?;
    final largeImg = json['primaryImage'] as String?;

    return Artwork(
      id: json['objectID'] as int,
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artistDisplayName'] as String? ?? 'Unknown',
      date: json['objectDate'] as String? ?? '',
      description: desc,
      medium: medium,
      dimensions: json['dimensions'] as String?,
      creditLine: json['creditLine'] as String?,
      placeOfOrigin: json['country'] as String?,
      department: json['department'] as String?,
      artistBio: artistBio,
      tags: tagList,
      imageUrl: _metProxyUrl(smallImg),
      imageUrlHigh: _metProxyUrl(largeImg),
    );
  }

  static String? _metProxyUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!kIsWeb) return url;
    return 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}';
  }

  static String? _buildMetDescription({
    required String artist,
    String? artistBio,
    String? medium,
    String? classification,
    String? culture,
    String? period,
    List<String> tags = const [],
  }) {
    final parts = <String>[];
    if (artist.isNotEmpty && artist != 'Unknown') {
      if (artistBio != null && artistBio.isNotEmpty) {
        parts.add('$artist ($artistBio).');
      }
    }
    if (classification != null && classification.isNotEmpty) {
      final c = (culture != null && culture.isNotEmpty) ? '$culture, ' : '';
      final p = (period != null && period.isNotEmpty) ? '$period era. ' : '';
      parts.add('$c$p$classification.');
    }
    if (medium != null && medium.isNotEmpty) parts.add('Medium: $medium.');
    if (tags.isNotEmpty) parts.add('Themes: ${tags.join(", ")}.');
    return parts.isEmpty ? null : parts.join(' ');
  }

  // ---------------------------------------------------------------------------
  // Art Institute of Chicago API
  // ---------------------------------------------------------------------------
  factory Artwork.fromAicJson(Map<String, dynamic> json) {
    final imageId = json['image_id'] as String?;
    return Artwork(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artist_title'] as String? ?? 'Unknown',
      date: json['date_display'] as String? ?? '',
      description: json['thumbnail']?['alt_text'] as String?,
      imageUrl: _aicImageUrl(imageId, 843),
      imageUrlHigh: _aicImageUrl(imageId, 1686),
    );
  }

  factory Artwork.fromAicDetailJson(Map<String, dynamic> json) {
    final imageId = json['image_id'] as String?;
    final desc = json['description'] as String?;
    final altText = json['thumbnail']?['alt_text'] as String?;
    return Artwork(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artist_title'] as String? ?? 'Unknown',
      date: json['date_display'] as String? ?? '',
      description: desc ?? altText,
      medium: json['medium_display'] as String?,
      dimensions: json['dimensions'] as String?,
      creditLine: json['credit_line'] as String?,
      placeOfOrigin: json['place_of_origin'] as String?,
      imageUrl: _aicImageUrl(imageId, 843),
      imageUrlHigh: _aicImageUrl(imageId, 1686),
    );
  }

  static const _aicProxy = 'https://impressionist-bot.vercel.app/api/image';

  static String? _aicImageUrl(String? imageId, int width) {
    if (imageId == null) return null;
    if (kIsWeb) {
      return 'https://www.artic.edu/iiif/2/$imageId/full/$width,/0/default.jpg';
    }
    return '$_aicProxy?id=$imageId&w=$width';
  }
}

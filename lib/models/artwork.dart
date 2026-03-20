import 'package:flutter/foundation.dart' show kIsWeb;

class Artwork {
  final int id;
  final String title;
  final String artist;
  final String date;
  final String? primaryImage;
  final String? primaryImageSmall;
  final String? description;
  final String? medium;
  final String? dimensions;
  final String? creditLine;
  final String? placeOfOrigin;
  final String? department;
  final String? artistBio;
  final String? classification;
  final String? culture;
  final String? period;
  final String? objectName;
  final List<String> tags;

  Artwork({
    required this.id,
    required this.title,
    required this.artist,
    required this.date,
    this.primaryImage,
    this.primaryImageSmall,
    this.description,
    this.medium,
    this.dimensions,
    this.creditLine,
    this.placeOfOrigin,
    this.department,
    this.artistBio,
    this.classification,
    this.culture,
    this.period,
    this.objectName,
    this.tags = const [],
  });

  factory Artwork.fromJson(Map<String, dynamic> json) {
    // tagsからterm一覧を取得
    final tagList = <String>[];
    final rawTags = json['tags'];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag is Map && tag['term'] != null) {
          tagList.add(tag['term'] as String);
        }
      }
    }

    final classification = json['classification'] as String?;
    final culture = json['culture'] as String?;
    final period = json['period'] as String?;
    final objectName = json['objectName'] as String?;
    final artistBio = json['artistDisplayBio'] as String?;
    final medium = json['medium'] as String?;

    // Met APIにはdescriptionがないため、メタデータから生成
    final desc = _buildDescription(
      artist: json['artistDisplayName'] as String? ?? '',
      artistBio: artistBio,
      medium: medium,
      classification: classification,
      culture: culture,
      period: period,
      tags: tagList,
    );

    return Artwork(
      id: json['objectID'] as int,
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artistDisplayName'] as String? ?? 'Unknown',
      date: json['objectDate'] as String? ?? '',
      primaryImage: json['primaryImage'] as String?,
      primaryImageSmall: json['primaryImageSmall'] as String?,
      description: desc,
      medium: medium,
      dimensions: json['dimensions'] as String?,
      creditLine: json['creditLine'] as String?,
      placeOfOrigin: json['country'] as String?,
      department: json['department'] as String?,
      artistBio: artistBio,
      classification: classification,
      culture: culture,
      period: period,
      objectName: objectName,
      tags: tagList,
    );
  }

  /// Met APIのメタデータから解説テキストを生成
  static String? _buildDescription({
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
      final cultureStr = (culture != null && culture.isNotEmpty) ? '$culture, ' : '';
      final periodStr = (period != null && period.isNotEmpty) ? '$period era. ' : '';
      parts.add('${cultureStr}$periodStr$classification.');
    }

    if (medium != null && medium.isNotEmpty) {
      parts.add('Medium: $medium.');
    }

    if (tags.isNotEmpty) {
      parts.add('Themes: ${tags.join(", ")}.');
    }

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  /// Web用CORSプロキシ（images.metmuseum.orgはCORSヘッダーなし）
  static String? _proxyUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!kIsWeb) return url;
    return 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}';
  }

  /// Met APIは画像URLを直接返すのでimageUrlはprimaryImageSmallを使用
  String? get imageUrl => _proxyUrl(primaryImageSmall);

  /// 高解像度はprimaryImageを使用
  String? get imageUrlHigh => _proxyUrl(primaryImage);
}

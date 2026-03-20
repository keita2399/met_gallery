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
  });

  factory Artwork.fromJson(Map<String, dynamic> json) {
    return Artwork(
      id: json['objectID'] as int,
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artistDisplayName'] as String? ?? 'Unknown',
      date: json['objectDate'] as String? ?? '',
      primaryImage: json['primaryImage'] as String?,
      primaryImageSmall: json['primaryImageSmall'] as String?,
      medium: json['medium'] as String?,
      dimensions: json['dimensions'] as String?,
      creditLine: json['creditLine'] as String?,
      placeOfOrigin: json['country'] as String?,
      department: json['department'] as String?,
      artistBio: json['artistDisplayBio'] as String?,
    );
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

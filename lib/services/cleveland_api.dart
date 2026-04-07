import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/artwork.dart';
import 'art_api.dart';
import 'image_proxy_service.dart';

/// Cleveland Museum of Art API実装（プロキシ経由）
class ClevelandApi extends ArtApi {
  static const _baseUrl = '$kBotBaseUrl/api/cleveland';

  @override
  Map<String, String> get imageHeaders => const {};

  @override
  Future<List<Artwork>> fetchHighlights({String? query, int limit = 20}) async {
    try {
      final params = <String, String>{
        'has_image': '1',
        'limit': limit.toString(),
        'skip': '0',
      };

      if (query != null && query.isNotEmpty) {
        // 画家名フィルターかキーワード検索か判定
        const artists = ['monet', 'van gogh', 'picasso', 'renoir', 'turner'];
        if (artists.contains(query.toLowerCase())) {
          params['artists'] = query;
        } else if (query == 'painting' || query == 'sculpture') {
          params['type'] = query;
        } else {
          params['q'] = query;
        }
      } else {
        // デフォルト: ハイライト作品
        params['is_highlight'] = '1';
      }

      final url = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final body = response.body.trimLeft();
      if (!body.startsWith('{')) return [];

      final data = jsonDecode(body);
      final List<dynamic> items = data['data'] ?? [];

      return items
          .map((json) => _parseArtwork(json as Map<String, dynamic>))
          .where((a) => a.imageUrl != null)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Artwork?> fetchArtworkDetail(int id) async {
    try {
      final url = Uri.parse('$_baseUrl/$id');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = response.body.trimLeft();
      if (!body.startsWith('{')) return null;

      final data = jsonDecode(body);
      final artData = data['data'] as Map<String, dynamic>?;
      if (artData == null) return null;

      return _parseArtwork(artData);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Artwork>> fetchPublicDomainWorks({String? query, int limit = 100}) async {
    return fetchHighlights(query: query, limit: limit);
  }

  static Artwork _parseArtwork(Map<String, dynamic> json) {
    final creators = json['creators'] as List<dynamic>?;
    String artist = 'Unknown';
    String? artistBio;

    if (creators != null && creators.isNotEmpty) {
      final creator = creators[0] as Map<String, dynamic>;
      artist = creator['description'] as String? ?? 'Unknown';
      // "Name (Nationality, birth–death)" から名前だけ抽出
      final parenIdx = artist.indexOf('(');
      if (parenIdx > 0) {
        artistBio = artist.substring(parenIdx);
        artist = artist.substring(0, parenIdx).trim();
      }
    }

    final images = json['images'] as Map<String, dynamic>?;
    String? imageUrl;
    String? imageUrlHigh;

    if (images != null) {
      final webUrl = (images['web'] as Map<String, dynamic>?)?['url'] as String?;
      final printUrl = (images['print'] as Map<String, dynamic>?)?['url'] as String?;
      // CDN画像もCORSなしのためプロキシ経由
      imageUrl = webUrl != null ? ImageProxyService.proxied(webUrl) : null;
      imageUrlHigh = printUrl != null ? ImageProxyService.proxied(printUrl) : imageUrl;
    }

    return Artwork(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      artist: artist,
      date: json['creation_date'] as String? ?? '',
      description: json['description'] as String?,
      medium: json['technique'] as String?,
      creditLine: json['creditline'] as String?,
      department: json['department'] as String?,
      artistBio: artistBio,
      placeOfOrigin: json['culture']?.toString(),
      imageUrl: imageUrl,
      imageUrlHigh: imageUrlHigh,
    );
  }
}

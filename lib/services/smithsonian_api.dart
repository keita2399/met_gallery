import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';
import 'art_api.dart';

/// Smithsonian Institution Open Access API実装（プロキシ経由）
class SmithsonianApi extends ArtApi {
  static const _proxyUrl = 'https://impressionist-bot.vercel.app/api/smithsonian';

  @override
  Map<String, String> get imageHeaders => const {};

  @override
  Future<List<Artwork>> fetchHighlights({String? query, int limit = 20}) async {
    try {
      final params = <String, String>{
        'q': query ?? '*',
        'rows': (limit * 3).toString(), // 画像なしも混ざるので多めに取得
        'category': 'art_design',
      };

      final url = Uri.parse(_proxyUrl).replace(queryParameters: params);
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final body = response.body.trimLeft();
      if (!body.startsWith('{')) return [];

      final data = jsonDecode(body);
      final List<dynamic> rows = data['response']?['rows'] ?? [];

      return rows
          .map((r) => _parseItem(r as Map<String, dynamic>))
          .where((a) => a.imageUrl != null)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Artwork?> fetchArtworkDetail(int id) async {
    // スミソニアンはIDが文字列型で長いため、ハイライトから再取得
    return null;
  }

  @override
  Future<List<Artwork>> fetchPublicDomainWorks({String? query, int limit = 100}) async {
    return fetchHighlights(query: query, limit: limit);
  }

  static Artwork _parseItem(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? 'Untitled';
    final id = (json['id'] as String? ?? '').hashCode.abs();
    final unitCode = json['unitCode'] as String? ?? '';

    final content = json['content'] as Map<String, dynamic>? ?? {};
    final desc = content['descriptiveNonRepeating'] as Map<String, dynamic>? ?? {};
    final freetext = content['freetext'] as Map<String, dynamic>? ?? {};

    // 画像取得
    String? imageUrl;
    final onlineMedia = desc['online_media'] as Map<String, dynamic>?;
    if (onlineMedia != null) {
      final media = onlineMedia['media'] as List<dynamic>?;
      if (media != null && media.isNotEmpty) {
        final m = media[0] as Map<String, dynamic>;
        // thumbnailまたはcontentから画像URL取得
        imageUrl = m['thumbnail'] as String? ?? m['content'] as String?;
        // プロキシ経由にする
        if (imageUrl != null) {
          imageUrl = 'https://impressionist-bot.vercel.app/api/image?met=${Uri.encodeComponent(imageUrl)}';
        }
      }
    }

    // 日付
    String date = '';
    final dates = freetext['date'] as List<dynamic>?;
    if (dates != null && dates.isNotEmpty) {
      date = (dates[0] as Map<String, dynamic>)['content'] as String? ?? '';
    }

    // 作者/名前
    String artist = _unitCodeToLabel(unitCode);
    final names = freetext['name'] as List<dynamic>?;
    if (names != null && names.isNotEmpty) {
      artist = (names[0] as Map<String, dynamic>)['content'] as String? ?? artist;
    }

    // 説明
    String? description;
    final notes = freetext['notes'] as List<dynamic>?;
    if (notes != null && notes.isNotEmpty) {
      description = (notes[0] as Map<String, dynamic>)['content'] as String?;
    }

    // 素材/技法
    String? medium;
    final physDesc = freetext['physicalDescription'] as List<dynamic>?;
    if (physDesc != null && physDesc.isNotEmpty) {
      medium = (physDesc[0] as Map<String, dynamic>)['content'] as String?;
    }

    return Artwork(
      id: id,
      title: title,
      artist: artist,
      date: date,
      description: description,
      medium: medium,
      department: _unitCodeToLabel(unitCode),
      imageUrl: imageUrl,
      imageUrlHigh: imageUrl,
    );
  }

  static String _unitCodeToLabel(String unitCode) {
    switch (unitCode) {
      case 'NASM': return '国立航空宇宙博物館';
      case 'NMNH': return '国立自然史博物館';
      case 'NMNHPALEOBIOLOGY': return '国立自然史博物館（古生物学）';
      case 'NMNHMINERALSCI': return '国立自然史博物館（鉱物学）';
      case 'NMAH': return '国立アメリカ歴史博物館';
      case 'NPG': return '国立肖像画美術館';
      case 'SAAM': return 'スミソニアンアメリカ美術館';
      case 'CHNDM': return 'クーパーヒューイット・デザイン博物館';
      case 'NPM': return '国立郵便博物館';
      case 'NMAAHC': return '国立アフリカ系アメリカ人歴史文化博物館';
      default: return 'スミソニアン博物館';
    }
  }
}

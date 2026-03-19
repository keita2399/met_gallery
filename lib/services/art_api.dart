import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';

class ArtApi {
  static const _baseUrl = 'https://collectionapi.metmuseum.org/public/collection/v1';

  /// Met Museum APIは画像URLを直接返すのでヘッダー不要
  static const imageHeaders = <String, String>{};

  /// 検索用: オブジェクトIDリストを取得
  static Future<List<int>> searchObjectIds({
    String? query,
    int? departmentId,
    bool hasImages = true,
    bool isPublicDomain = true,
    bool isHighlight = false,
  }) async {
    final params = <String, String>{};
    if (hasImages) params['hasImages'] = 'true';
    if (isPublicDomain) params['isPublicDomain'] = 'true';
    if (isHighlight) params['isHighlight'] = 'true';
    if (departmentId != null) params['departmentId'] = departmentId.toString();
    // qは必須パラメータ
    params['q'] = query ?? '*';

    final url = Uri.parse('$_baseUrl/search').replace(queryParameters: params);
    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to search: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final List<dynamic>? ids = data['objectIDs'];
    return ids?.cast<int>() ?? [];
  }

  /// 作品詳細を取得
  static Future<Artwork?> fetchArtworkDetail(int id) async {
    final url = Uri.parse('$_baseUrl/objects/$id');
    final response = await http.get(url);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    if (data['objectID'] == null) return null;

    return Artwork.fromJson(data as Map<String, dynamic>);
  }

  /// メイン取得メソッド: ハイライト作品を並列取得
  static Future<List<Artwork>> fetchHighlights({
    int? departmentId,
    String? query,
    int limit = 80,
  }) async {
    final ids = await searchObjectIds(
      query: query ?? '*',
      departmentId: departmentId,
      isHighlight: true,
    );

    return _fetchArtworksByIds(ids, limit: limit);
  }

  /// 公開ドメイン作品を取得
  static Future<List<Artwork>> fetchPublicDomainWorks({
    String? query,
    int? departmentId,
    int limit = 100,
  }) async {
    final ids = await searchObjectIds(
      query: query ?? '*',
      departmentId: departmentId,
    );

    return _fetchArtworksByIds(ids, limit: limit);
  }

  /// IDリストから並列で作品詳細を取得（10件ずつバッチ）
  static Future<List<Artwork>> _fetchArtworksByIds(List<int> ids, {int limit = 80}) async {
    final targetIds = ids.take(limit).toList();
    final artworks = <Artwork>[];

    for (var i = 0; i < targetIds.length; i += 10) {
      final batch = targetIds.skip(i).take(10);
      final futures = batch.map((id) => fetchArtworkDetail(id));
      final results = await Future.wait(futures);
      for (final artwork in results) {
        if (artwork != null && artwork.imageUrl != null && artwork.imageUrl!.isNotEmpty) {
          artworks.add(artwork);
        }
      }
    }

    return artworks;
  }
}

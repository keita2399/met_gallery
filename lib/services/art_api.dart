import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';

class ArtApi {
  static const _baseUrl = 'https://collectionapi.metmuseum.org/public/collection/v1';

  /// Met Museum APIは画像URLを直接返すのでヘッダー不要
  static const imageHeaders = <String, String>{};

  /// HTTP GETリクエスト（Imperva CDNチャレンジ対策付き）
  /// HTMLが返ってきた場合は最大3回リトライ
  static Future<http.Response> _get(Uri url) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final response = await http.get(url);
      if (response.statusCode != 200) return response;

      // Imperva CDNがHTMLチャレンジを返す場合の検出
      final body = response.body.trimLeft();
      if (body.startsWith('<') || body.startsWith('<!DOCTYPE')) {
        // HTMLが返ってきた場合、少し待ってリトライ
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        continue;
      }
      return response;
    }
    // 3回リトライしてもダメなら最後のレスポンスを返す
    return await http.get(url);
  }

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
    final response = await _get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to search: ${response.statusCode}');
    }

    final body = response.body.trimLeft();
    if (body.startsWith('<')) {
      throw Exception('API returned HTML instead of JSON (CDN block)');
    }

    final data = jsonDecode(body);
    final List<dynamic>? ids = data['objectIDs'];
    return ids?.cast<int>() ?? [];
  }

  /// 作品詳細を取得
  static Future<Artwork?> fetchArtworkDetail(int id) async {
    final url = Uri.parse('$_baseUrl/objects/$id');
    final response = await _get(url);

    if (response.statusCode != 200) return null;

    final body = response.body.trimLeft();
    if (body.startsWith('<')) return null;

    final data = jsonDecode(body);
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

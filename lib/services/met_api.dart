import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';
import 'art_api.dart';

/// Metropolitan Museum of Art API実装
class MetApi extends ArtApi {
  static const _baseUrl = 'https://collectionapi.metmuseum.org/public/collection/v1';

  @override
  Map<String, String> get imageHeaders => const {};

  static bool _isJson(String body) {
    final trimmed = body.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  static dynamic _safeDecode(String body) {
    if (!_isJson(body)) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// CDNチャレンジ対策付きGETリクエスト
  static Future<http.Response> _get(Uri url) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(url);
        if (response.statusCode != 200) return response;
        if (_isJson(response.body)) return response;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      } catch (_) {
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return await http.get(url);
  }

  Future<List<int>> searchObjectIds({
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
    params['q'] = query ?? '*';

    final url = Uri.parse('$_baseUrl/search').replace(queryParameters: params);
    final response = await _get(url);

    if (response.statusCode != 200) {
      throw Exception('検索に失敗しました (${response.statusCode})');
    }

    final data = _safeDecode(response.body);
    if (data == null) {
      throw Exception('APIがブロックされています。しばらく待ってから再試行してください。');
    }

    final List<dynamic>? ids = data['objectIDs'];
    return ids?.cast<int>() ?? [];
  }

  @override
  Future<Artwork?> fetchArtworkDetail(int id) async {
    final url = Uri.parse('$_baseUrl/objects/$id');
    try {
      final response = await _get(url);
      if (response.statusCode != 200) return null;

      final data = _safeDecode(response.body);
      if (data == null || data['objectID'] == null) return null;

      return Artwork.fromMetJson(data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Artwork>> fetchHighlights({String? query, int limit = 20}) async {
    try {
      final ids = await searchObjectIds(
        query: query ?? '*',
        isHighlight: true,
      );
      return _fetchArtworksByIds(ids, limit: limit);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Artwork>> fetchPublicDomainWorks({String? query, int limit = 100}) async {
    try {
      final ids = await searchObjectIds(query: query ?? '*');
      return _fetchArtworksByIds(ids, limit: limit);
    } catch (_) {
      return [];
    }
  }

  Future<List<Artwork>> _fetchArtworksByIds(List<int> ids, {int limit = 80}) async {
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';
import 'art_api.dart';

/// Art Institute of Chicago API実装
class AicApi extends ArtApi {
  static const _baseUrl = 'https://api.artic.edu/api/v1';
  static const _fields = 'id,title,artist_title,date_display,image_id,thumbnail,style_titles';

  @override
  Map<String, String> get imageHeaders => const {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
  };

  static const impressionistArtists = [
    'Claude Monet', 'Pierre-Auguste Renoir', 'Edgar Degas',
    'Camille Pissarro', 'Alfred Sisley', 'Berthe Morisot',
    'Gustave Caillebotte', 'Vincent van Gogh', 'Paul Cézanne',
    'Paul Gauguin', 'Georges Seurat', 'Henri de Toulouse-Lautrec',
    'Paul Signac', 'Édouard Manet', 'Mary Cassatt',
  ];

  @override
  Future<List<Artwork>> fetchHighlights({String? query, int limit = 20}) async {
    return _fetchImpressionistWorks(artistFilter: query, limit: limit);
  }

  @override
  Future<List<Artwork>> fetchPublicDomainWorks({String? query, int limit = 100}) async {
    return _fetchImpressionistWorks(artistFilter: query, limit: limit);
  }

  @override
  Future<Artwork?> fetchArtworkDetail(int id) async {
    final url = Uri.parse(
      '$_baseUrl/artworks/$id?fields=$_fields,description,publication_history,exhibition_history,place_of_origin,medium_display,dimensions,credit_line',
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'ImpressionGallery/1.0 (Flutter App)',
      });
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final artData = data['data'] as Map<String, dynamic>?;
      if (artData == null) return null;

      return Artwork.fromAicDetailJson(artData);
    } catch (_) {
      return null;
    }
  }

  Future<List<Artwork>> _fetchImpressionistWorks({
    int page = 1,
    int limit = 100,
    String? artistFilter,
  }) async {
    final url = Uri.parse('$_baseUrl/artworks/search?fields=$_fields&page=$page&limit=$limit');

    final artists = artistFilter != null ? [artistFilter] : impressionistArtists;

    final body = jsonEncode({
      "query": {
        "bool": {
          "must": [
            {"terms": {"artist_title.keyword": artists}},
            {"term": {"is_public_domain": true}},
            {"exists": {"field": "image_id"}},
          ]
        }
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'ImpressionGallery/1.0 (Flutter App)',
        },
        body: body,
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final List<dynamic> items = data['data'] ?? [];

      return items
          .map((json) => Artwork.fromAicJson(json as Map<String, dynamic>))
          .where((a) => a.imageUrl != null)
          .toList();
    } catch (_) {
      return [];
    }
  }
}

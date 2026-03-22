import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';
import 'art_api.dart';

/// Wikidata SPARQL経由で特定画家の作品を取得する汎用API
/// フェルメール、レンブラント等、画家ごとにインスタンスを作成
class WikidataArtistApi extends ArtApi {
  final String artistQid;      // Wikidata ID (例: Q5598)
  final String artistNameJa;   // 日本語名 (例: レンブラント)
  final String artistCountry;  // 国 (例: オランダ)
  final Map<String, bool Function(Artwork)>? filters; // カスタムフィルター

  static const _sparqlProxy = 'https://impressionist-bot.vercel.app/api/sparql';

  WikidataArtistApi({
    required this.artistQid,
    required this.artistNameJa,
    this.artistCountry = '',
    this.filters,
  });

  @override
  Map<String, String> get imageHeaders => const {};

  static String _toImageUrl(String url) {
    if (url.startsWith('http://')) {
      url = 'https://${url.substring(7)}';
    }
    return 'https://impressionist-bot.vercel.app/api/image?met=${Uri.encodeComponent(url)}';
  }

  Future<List<Artwork>> _fetchAllWorks() async {
    final query = '''
SELECT ?painting ?paintingLabel ?image ?collectionLabel ?inception ?paintingDescription WHERE {
  ?painting wdt:P170 wd:$artistQid .
  ?painting wdt:P31 wd:Q3305213 .
  ?painting wdt:P18 ?image .
  OPTIONAL { ?painting wdt:P195 ?collection . }
  OPTIONAL { ?painting wdt:P571 ?inception . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en" . }
}
ORDER BY ?inception
''';

    try {
      final url = Uri.parse(_sparqlProxy).replace(queryParameters: {
        'query': query.trim(),
      });

      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final body = response.body.trimLeft();
      if (!body.startsWith('{')) return [];

      final data = jsonDecode(body);
      final bindings = data['results']['bindings'] as List;

      final seen = <String>{};
      final artworks = <Artwork>[];

      for (final b in bindings) {
        final wikidataUri = b['painting']['value'] as String;
        final id = wikidataUri.split('/').last;
        if (seen.contains(id)) continue;
        seen.add(id);

        final title = b['paintingLabel']['value'] as String;
        final imageUrl = b['image']?['value'] as String?;
        final collection = b['collectionLabel']?['value'] as String?;
        final inception = b['inception']?['value'] as String?;
        final year = inception != null && inception.length >= 4
            ? inception.substring(0, 4)
            : '';
        final description = b['paintingDescription']?['value'] as String?;

        if (imageUrl == null) continue;

        artworks.add(Artwork(
          id: id.hashCode.abs(),
          title: title,
          artist: artistNameJa,
          date: year,
          description: description,
          medium: collection != null ? '所蔵: $collection' : null,
          placeOfOrigin: artistCountry,
          imageUrl: _toImageUrl(imageUrl),
          imageUrlHigh: _toImageUrl(imageUrl),
        ));
      }

      return artworks;
    } catch (_) {
      return [];
    }
  }

  List<Artwork>? _cache;

  Future<List<Artwork>> _getAll() async {
    _cache ??= await _fetchAllWorks();
    return _cache!;
  }

  @override
  Future<List<Artwork>> fetchHighlights({String? query, int limit = 20}) async {
    var works = await _getAll();

    // フィルター適用
    if (query != null && filters != null && filters!.containsKey(query)) {
      works = works.where(filters![query]!).toList();
    }

    works.shuffle();
    return works.take(limit).toList();
  }

  @override
  Future<Artwork?> fetchArtworkDetail(int id) async {
    final works = await _getAll();
    try {
      return works.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Artwork>> fetchPublicDomainWorks({String? query, int limit = 100}) async {
    return fetchHighlights(query: query, limit: limit);
  }
}

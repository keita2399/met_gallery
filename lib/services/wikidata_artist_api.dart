import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/artwork.dart';
import 'art_api.dart';
import 'image_proxy_service.dart';

/// Wikidata SPARQL経由で特定画家の作品を取得する汎用API
/// フェルメール、レンブラント等、画家ごとにインスタンスを作成
class WikidataArtistApi extends ArtApi {
  final String artistQid;      // Wikidata ID (例: Q5598)
  final String artistNameJa;   // 日本語名 (例: レンブラント)
  final String artistCountry;  // 国 (例: オランダ)
  final Map<String, bool Function(Artwork)>? filters; // カスタムフィルター

  static const _sparqlDirect = 'https://query.wikidata.org/sparql';
  static const _sparqlProxy = '$kBotBaseUrl/api/sparql';

  WikidataArtistApi({
    required this.artistQid,
    required this.artistNameJa,
    this.artistCountry = '',
    this.filters,
  });

  @override
  Map<String, String> get imageHeaders => const {};


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
      // Try direct Wikidata first, fallback to proxy
      final directUrl = Uri.parse(
        '$_sparqlDirect?format=json&query=${Uri.encodeComponent(query.trim())}',
      );
      final proxyUrl = Uri.parse(
        '$_sparqlProxy?query=${Uri.encodeComponent(query.trim())}',
      );

      http.Response response;
      try {
        response = await http.get(directUrl).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) throw Exception('Direct failed: ${response.statusCode}');
      } catch (_) {
        response = await http.get(proxyUrl).timeout(const Duration(seconds: 25));
      }

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
        // Skip items without proper labels (shows as QID)
        if (title.startsWith('Q') && RegExp(r'^Q\d+$').hasMatch(title)) continue;

        artworks.add(Artwork(
          id: id.hashCode.abs(),
          title: title,
          artist: artistNameJa,
          date: year,
          description: description,
          medium: collection != null ? '所蔵: $collection' : null,
          placeOfOrigin: artistCountry,
          imageUrl: ImageProxyService.wikimediaThumb(imageUrl),
          imageUrlHigh: ImageProxyService.proxied(imageUrl),
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

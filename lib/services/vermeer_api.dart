import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artwork.dart';
import 'art_api.dart';

/// フェルメール全作品API（Wikidata SPARQL経由）
class VermeerApi extends ArtApi {
  static const _sparqlEndpoint = 'https://query.wikidata.org/sparql';

  @override
  Map<String, String> get imageHeaders => const {};

  /// Wikimedia Commons の Special:FilePath URL を直接画像URLに変換
  /// http://commons.wikimedia.org/wiki/Special:FilePath/File.jpg
  /// → https://commons.wikimedia.org/wiki/Special:FilePath/File.jpg
  /// Image.networkがhttpsリダイレクトを追跡できるようにする
  static String _toImageUrl(String url) {
    // httpをhttpsに変換
    if (url.startsWith('http://')) {
      url = 'https://${url.substring(7)}';
    }
    // スペースをアンダースコアに（Wikimedia規約）
    url = url.replaceAll('%20', '_').replaceAll(' ', '_');
    return url;
  }

  /// Wikidataからフェルメール全作品を取得
  static Future<List<Artwork>> _fetchAllWorks() async {
    const query = '''
SELECT ?painting ?paintingLabel ?image ?collectionLabel ?inception ?paintingDescription WHERE {
  ?painting wdt:P170 wd:Q41264 .
  ?painting wdt:P31 wd:Q3305213 .
  ?painting wdt:P18 ?image .
  OPTIONAL { ?painting wdt:P195 ?collection . }
  OPTIONAL { ?painting wdt:P571 ?inception . }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "ja,en" . }
}
ORDER BY ?inception
''';

    try {
      final url = Uri.parse(
        '$_sparqlEndpoint?format=json&query=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'User-Agent': 'VermeerSanpo/1.0 (Flutter App)',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return [];

      final body = response.body.trimLeft();
      if (!body.startsWith('{')) return [];

      final data = jsonDecode(body);
      final bindings = data['results']['bindings'] as List;

      // 重複排除（Wikidataは複数コレクションで重複する）
      final seen = <String>{};
      final artworks = <Artwork>[];

      for (final b in bindings) {
        final wikidataUri = b['painting']['value'] as String;
        final id = wikidataUri.split('/').last; // Q12345形式
        if (seen.contains(id)) continue;
        seen.add(id);

        final title = b['paintingLabel']['value'] as String;
        final imageUrl = b['image']?['value'] as String?;
        final collection = b['collectionLabel']?['value'] as String?;
        final inception = b['inception']?['value'] as String?;
        final year = inception != null ? inception.substring(0, 4) : '';
        final description = b['paintingDescription']?['value'] as String?;

        if (imageUrl == null) continue;

        final resolvedUrl = _toImageUrl(imageUrl);

        artworks.add(Artwork(
          id: id.hashCode.abs(),
          title: title,
          artist: 'ヨハネス・フェルメール',
          date: year,
          description: description,
          medium: collection != null ? '所蔵: $collection' : null,
          placeOfOrigin: 'オランダ',
          imageUrl: resolvedUrl,
          imageUrlHigh: resolvedUrl,
        ));
      }

      return artworks;
    } catch (_) {
      return [];
    }
  }

  // キャッシュ（1回取得すればアプリ起動中は使い回す）
  static List<Artwork>? _cache;

  Future<List<Artwork>> _getAll() async {
    _cache ??= await _fetchAllWorks();
    return _cache!;
  }

  @override
  Future<List<Artwork>> fetchHighlights({String? query, int limit = 20}) async {
    var works = await _getAll();

    // 年代フィルター
    if (query != null) {
      if (query == '1650s') {
        works = works.where((w) => w.date.startsWith('165')).toList();
      } else if (query == '1660s') {
        works = works.where((w) => w.date.startsWith('166')).toList();
      } else if (query == '1670s') {
        works = works.where((w) => w.date.startsWith('167')).toList();
      }
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

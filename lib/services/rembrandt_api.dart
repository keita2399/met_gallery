import '../models/artwork.dart';
import 'wikidata_artist_api.dart';

/// レンブラント全作品API（WikidataArtistApiのレンブラント設定）
class RembrandtApi extends WikidataArtistApi {
  RembrandtApi()
      : super(
          artistQid: 'Q5598',
          artistNameJa: 'レンブラント・ファン・レイン',
          artistCountry: 'オランダ',
          filters: {
            'portrait': (Artwork w) =>
                w.title.toLowerCase().contains('portrait') ||
                w.title.contains('肖像'),
            'self-portrait': (Artwork w) =>
                w.title.toLowerCase().contains('self-portrait') ||
                w.title.contains('自画像'),
            'religious': (Artwork w) =>
                w.title.toLowerCase().contains('christ') ||
                w.title.toLowerCase().contains('moses') ||
                w.title.toLowerCase().contains('david') ||
                w.title.toLowerCase().contains('abraham') ||
                w.title.toLowerCase().contains('saint') ||
                w.title.contains('キリスト'),
            'landscape': (Artwork w) =>
                w.title.toLowerCase().contains('landscape') ||
                w.title.contains('風景'),
            'history': (Artwork w) =>
                w.title.toLowerCase().contains('night watch') ||
                w.title.toLowerCase().contains('anatomy') ||
                w.title.toLowerCase().contains('conspiracy') ||
                w.title.contains('夜警'),
          },
        );
}

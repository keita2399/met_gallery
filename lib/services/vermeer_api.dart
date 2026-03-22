import '../models/artwork.dart';
import 'wikidata_artist_api.dart';

/// フェルメール全作品API（WikidataArtistApiのフェルメール設定）
class VermeerApi extends WikidataArtistApi {
  VermeerApi()
      : super(
          artistQid: 'Q41264',
          artistNameJa: 'ヨハネス・フェルメール',
          artistCountry: 'オランダ',
          filters: {
            '1650s': (Artwork w) => w.date.startsWith('165'),
            '1660s': (Artwork w) => w.date.startsWith('166'),
            '1670s': (Artwork w) => w.date.startsWith('167'),
          },
        );
}

import '../models/artwork.dart';

/// 美術館API共通インターフェース
/// 新しい美術館を追加する場合はこのクラスを継承する
abstract class ArtApi {
  /// 画像読み込み時に必要なHTTPヘッダー
  Map<String, String> get imageHeaders;

  /// ハイライト作品を取得
  Future<List<Artwork>> fetchHighlights({String? query, int limit = 20});

  /// 作品詳細を取得
  Future<Artwork?> fetchArtworkDetail(int id);

  /// 検索（公開ドメイン作品）
  Future<List<Artwork>> fetchPublicDomainWorks({String? query, int limit = 100});
}

/// グローバルにアクセスできるAPIインスタンス
/// main_xxx.dart で初期化する
late final ArtApi artApi;

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/constants.dart';

/// 画像URLのプロキシ変換を一元管理するサービス
/// Cleveland, Smithsonian, Wikidata, AIC, Met のバラバラなプロキシ処理をここに集約
class ImageProxyService {
  /// 汎用URL → ボットプロキシ経由URL
  /// Cleveland, Smithsonian 等のCORSブロック回避に使用
  static String proxied(String url) {
    if (url.startsWith('http://')) url = 'https://${url.substring(7)}';
    return '$kBotBaseUrl/api/image?met=${Uri.encodeComponent(url)}';
  }

  /// Wikimedia URL → サムネイル生成済みプロキシURL
  /// WikidataArtistApi（Vermeer, Monet, Rembrandt等）で使用
  static String wikimediaThumb(String url, [int? width]) {
    final w = width ?? optimalThumbWidth();
    if (url.startsWith('http://')) url = 'https://${url.substring(7)}';
    if (url.contains('upload.wikimedia.org') && !url.contains('/thumb/')) {
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;
      final thumbPath = uri.path.replaceFirst('/commons/', '/commons/thumb/');
      url = '${uri.scheme}://${uri.host}$thumbPath/${w}px-$fileName';
    }
    return '$kBotBaseUrl/api/image?met=${Uri.encodeComponent(url)}';
  }

  /// AIC (Art Institute of Chicago) 画像ID → プロキシURL
  static String? aicImage(String? imageId, int width) {
    if (imageId == null) return null;
    return '$kBotBaseUrl/api/image?id=$imageId&w=$width';
  }

  /// Met Museum URL → プロキシURL（Web時のみ wsrv.nl 経由）
  static String? metImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (!kIsWeb) return url;
    return 'https://wsrv.nl/?url=${Uri.encodeComponent(url)}';
  }

  /// デバイス画面幅に合わせた最適なサムネイル幅を返す（400〜1600px）
  static int optimalThumbWidth() {
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) return 800;
    final pixelWidth = (view.physicalSize.width / view.devicePixelRatio * view.devicePixelRatio).round();
    return pixelWidth.clamp(400, 1600);
  }
}

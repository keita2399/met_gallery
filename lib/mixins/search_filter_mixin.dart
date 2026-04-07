import 'package:flutter/material.dart';
import '../models/artwork.dart';
import '../services/translate_service.dart';

/// 検索・タイトル翻訳キャッシュの共通実装
///
/// gallery_screen と search_screen で重複していたロジックを統一
/// 使用例:
///   class _MyScreenState extends State<MyScreen> with SearchFilterMixin {
///     void _onSearchChanged(String q) {
///       setState(() => filteredWorks = filterByQuery(allWorks, q));
///     }
///   }
mixin SearchFilterMixin<T extends StatefulWidget> on State<T> {
  /// タイトル翻訳キャッシュ（artwork.id → 日本語訳）
  final Map<int, String> translatedTitles = {};

  /// 検索クエリで作品リストをフィルタリング
  /// 作品名（英/日）・画家名（英/日）・年代を対象に検索
  List<Artwork> filterByQuery(List<Artwork> works, String query) {
    if (query.isEmpty) return works;
    final lower = query.toLowerCase();
    return works.where((a) {
      final jaTitle = (translatedTitles[a.id] ?? '').toLowerCase();
      final jaArtist = TranslateService.translateArtist(a.artist).toLowerCase();
      return a.title.toLowerCase().contains(lower) ||
          a.artist.toLowerCase().contains(lower) ||
          jaArtist.contains(lower) ||
          jaTitle.contains(lower) ||
          a.date.toLowerCase().contains(lower);
    }).toList();
  }

  /// 1件のタイトルを翻訳してキャッシュ
  Future<void> translateTitle(Artwork artwork) async {
    if (translatedTitles.containsKey(artwork.id)) return;
    final translated = await TranslateService.toJapanese(artwork.title);
    if (mounted) {
      setState(() => translatedTitles[artwork.id] = translated);
    }
  }

  /// 複数作品のタイトルを順次翻訳
  Future<void> translateAll(List<Artwork> works) async {
    for (final w in works) {
      await translateTitle(w);
    }
  }
}

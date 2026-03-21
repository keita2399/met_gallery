import 'package:flutter/material.dart';

/// アプリ設定の基底クラス
/// 美術館・画家シリーズごとにサブクラスを作成する
class AppConfig {
  final String appName;
  final String appNameEn;
  final String splashIcon;
  final Color themeColor;
  final String museumUrl;
  final String appUrl;

  /// ギャラリーのフィルターカテゴリ
  final List<FilterCategory> filterCategories;

  /// ボトムナビの「年表」で使うデータを持つか
  final bool hasTimeline;

  /// アーティストプロフィール画面を持つか
  final bool hasArtistProfiles;

  const AppConfig({
    required this.appName,
    required this.appNameEn,
    required this.splashIcon,
    required this.themeColor,
    required this.museumUrl,
    required this.appUrl,
    this.filterCategories = const [],
    this.hasTimeline = false,
    this.hasArtistProfiles = false,
  });
}

class FilterCategory {
  final String label;
  final String? query;
  const FilterCategory({required this.label, this.query});
}

/// グローバルにアクセスできる現在の設定
/// main_xxx.dart で初期化する
late final AppConfig appConfig;

import 'package:flutter/material.dart';
import 'app_config.dart';

const metConfig = AppConfig(
  appName: 'メトロポリタンさんぽ',
  appNameEn: 'Metropolitan Museum Walk',
  splashIcon: '\u{1F3EB}', // 🏛
  themeColor: Color(0xFF8B0000),
  museumUrl: 'https://www.metmuseum.org/art/collection/search',
  appUrl: 'https://impression-gallery.vercel.app',
  hasTimeline: false,
  hasArtistProfiles: false,
  filterCategories: [
    FilterCategory(label: 'すべて'),
    FilterCategory(label: '絵画 (Paintings)', query: 'painting'),
    FilterCategory(label: '彫刻 (Sculpture)', query: 'sculpture'),
    FilterCategory(label: '写真 (Photographs)', query: 'photograph'),
    FilterCategory(label: '日本美術 (Japanese)', query: 'japanese'),
    FilterCategory(label: 'エジプト (Egyptian)', query: 'egyptian'),
    FilterCategory(label: 'ギリシャ・ローマ (Greek Roman)', query: 'greek roman'),
    FilterCategory(label: '中世 (Medieval)', query: 'medieval'),
    FilterCategory(label: '現代美術 (Modern)', query: 'modern art'),
  ],
);

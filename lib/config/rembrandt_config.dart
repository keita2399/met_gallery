import 'package:flutter/material.dart';
import 'app_config.dart';

const rembrandtConfig = AppConfig(
  appName: 'レンブラントさんぽ',
  appNameEn: 'Rembrandt Walk',
  splashIcon: '\u{1F3A8}', // 🎨
  themeColor: Color(0xFF4E342E),
  museumUrl: 'https://www.wikidata.org/wiki',
  appUrl: 'https://sanpo-rembrandt.vercel.app',
  hasTimeline: false,
  hasArtistProfiles: false,
  artworkLabel: '名画',
  filterCategories: [
    FilterCategory(label: 'すべて'),
    FilterCategory(label: '肖像画', query: 'portrait'),
    FilterCategory(label: '自画像', query: 'self-portrait'),
    FilterCategory(label: '宗教画', query: 'religious'),
    FilterCategory(label: '風景画', query: 'landscape'),
    FilterCategory(label: '歴史画', query: 'history'),
  ],
);

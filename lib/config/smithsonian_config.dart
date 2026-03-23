import 'package:flutter/material.dart';
import 'app_config.dart';

const smithsonianConfig = AppConfig(
  appName: 'スミソニアン博物館さんぽ',
  appNameEn: 'Smithsonian Walk',
  splashIcon: '\u{1F996}', // 🦖
  themeColor: Color(0xFF1B5E20),
  museumUrl: 'https://www.si.edu/object',
  appUrl: 'https://sanpo-smithsonian.vercel.app',
  hasTimeline: false,
  hasArtistProfiles: false,
  artworkLabel: '展示品',
  filterCategories: [
    FilterCategory(label: 'すべて'),
    FilterCategory(label: '恐竜・化石', query: 'dinosaur fossil'),
    FilterCategory(label: '宝石・鉱物', query: 'gem mineral'),
    FilterCategory(label: '航空・宇宙', query: 'aircraft spacecraft'),
    FilterCategory(label: 'アメリカ史', query: 'american history'),
    FilterCategory(label: '肖像画', query: 'portrait'),
    FilterCategory(label: '写真', query: 'photograph'),
    FilterCategory(label: '発明・技術', query: 'invention technology'),
  ],
);

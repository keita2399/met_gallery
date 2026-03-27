import 'package:flutter/material.dart';
import 'app_config.dart';

const monetConfig = AppConfig(
  appName: 'モネさんぽ',
  appNameEn: 'Monet Walk',
  splashIcon: '\u{1F338}', // 🌸
  themeColor: Color(0xFF5C6BC0),
  museumUrl: 'https://www.wikidata.org/wiki',
  appUrl: 'https://sanpo-monet.vercel.app',
  hasTimeline: false,
  has3dGallery: true,
  hasArtistProfiles: false,
  artworkLabel: '名画',
  filterCategories: [
    FilterCategory(label: 'すべて'),
    FilterCategory(label: '1860年代', query: '1860s'),
    FilterCategory(label: '1870年代', query: '1870s'),
    FilterCategory(label: '1880年代', query: '1880s'),
    FilterCategory(label: '1890年代', query: '1890s'),
    FilterCategory(label: '1900年代', query: '1900s'),
    FilterCategory(label: '1910年代', query: '1910s'),
    FilterCategory(label: '1920年代', query: '1920s'),
  ],
);

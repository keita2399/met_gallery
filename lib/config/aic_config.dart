import 'package:flutter/material.dart';
import 'app_config.dart';

const aicConfig = AppConfig(
  appName: '印象派さんぽ',
  appNameEn: 'Impressionist Walk',
  splashIcon: '\u{1F3A8}', // 🎨
  themeColor: Color(0xFF1A237E),
  museumUrl: 'https://www.artic.edu/artworks',
  appUrl: 'https://impressiongallery.vercel.app',
  hasTimeline: true,
  hasArtistProfiles: true,
  filterCategories: [
    FilterCategory(label: 'すべて'),
    FilterCategory(label: 'クロード・モネ', query: 'Claude Monet'),
    FilterCategory(label: 'ピエール＝オーギュスト・ルノワール', query: 'Pierre-Auguste Renoir'),
    FilterCategory(label: 'エドガー・ドガ', query: 'Edgar Degas'),
    FilterCategory(label: 'ポール・セザンヌ', query: 'Paul Cézanne'),
    FilterCategory(label: 'フィンセント・ファン・ゴッホ', query: 'Vincent van Gogh'),
    FilterCategory(label: 'ベルト・モリゾ', query: 'Berthe Morisot'),
    FilterCategory(label: 'メアリー・カサット', query: 'Mary Cassatt'),
    FilterCategory(label: 'カミーユ・ピサロ', query: 'Camille Pissarro'),
    FilterCategory(label: 'アルフレッド・シスレー', query: 'Alfred Sisley'),
    FilterCategory(label: 'ジョルジュ・スーラ', query: 'Georges Seurat'),
  ],
);

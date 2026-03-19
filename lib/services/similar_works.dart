import 'dart:math';
import 'package:flutter/material.dart';
import '../models/artwork.dart';
import 'art_api.dart';
import 'color_palette.dart';

class SimilarWork {
  final Artwork artwork;
  final double similarity; // 0.0 ~ 1.0 (1.0 = identical)
  const SimilarWork(this.artwork, this.similarity);
}

class SimilarWorksService {
  static final SimilarWorksService _instance = SimilarWorksService._();
  static SimilarWorksService get instance => _instance;
  SimilarWorksService._();

  // Cache: artwork ID → palette
  final Map<int, List<ColorInfo>> _paletteCache = {};
  List<Artwork>? _allWorks;
  bool _loading = false;

  /// Load all works and extract palettes (runs once, then cached)
  Future<void> _ensureLoaded() async {
    if (_allWorks != null || _loading) return;
    _loading = true;
    try {
      _allWorks = await ArtApi.fetchHighlights(limit: 80);
    } catch (_) {
      _allWorks = [];
    }
    _loading = false;
  }

  /// Extract palette for a single artwork (with caching)
  Future<List<ColorInfo>> _getPalette(Artwork artwork) async {
    if (_paletteCache.containsKey(artwork.id)) return _paletteCache[artwork.id]!;
    final url = artwork.imageUrl;
    if (url == null) return [];
    try {
      final palette = await ColorPaletteExtractor.extract(url, count: 5);
      _paletteCache[artwork.id] = palette;
      return palette;
    } catch (_) {
      return [];
    }
  }

  /// Calculate color similarity between two palettes (0.0 ~ 1.0)
  double _calcSimilarity(List<ColorInfo> a, List<ColorInfo> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    double totalScore = 0;
    double totalWeight = 0;

    // For each color in palette A, find the closest match in B
    for (final ca in a) {
      double bestDist = double.infinity;
      for (final cb in b) {
        final dist = _colorDistance(ca.color, cb.color);
        if (dist < bestDist) bestDist = dist;
      }
      // Weight by percentage (dominant colors matter more)
      final weight = ca.percentage / 100.0;
      // Convert distance to similarity (max distance ~441 for RGB)
      final sim = 1.0 - (bestDist / 441.0).clamp(0.0, 1.0);
      totalScore += sim * weight;
      totalWeight += weight;
    }

    // Also check B→A for symmetry
    for (final cb in b) {
      double bestDist = double.infinity;
      for (final ca in a) {
        final dist = _colorDistance(ca.color, cb.color);
        if (dist < bestDist) bestDist = dist;
      }
      final weight = cb.percentage / 100.0;
      final sim = 1.0 - (bestDist / 441.0).clamp(0.0, 1.0);
      totalScore += sim * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? totalScore / totalWeight : 0.0;
  }

  /// Euclidean distance in RGB space
  double _colorDistance(Color a, Color b) {
    final dr = a.red - b.red;
    final dg = a.green - b.green;
    final db = a.blue - b.blue;
    return sqrt(dr * dr + dg * dg + db * db);
  }

  /// Find similar works to the given artwork
  /// Returns top [count] similar works, excluding the artwork itself
  Future<List<SimilarWork>> findSimilar(Artwork target, {int count = 4}) async {
    await _ensureLoaded();
    if (_allWorks == null || _allWorks!.isEmpty) return [];

    final targetPalette = await _getPalette(target);
    if (targetPalette.isEmpty) return [];

    // Compare with a subset for performance (first 50 works with images)
    final candidates = _allWorks!
        .where((w) => w.id != target.id && w.imageUrl != null)
        .take(50)
        .toList();

    // Extract palettes in parallel (limited concurrency)
    final results = <SimilarWork>[];
    for (final work in candidates) {
      final palette = await _getPalette(work);
      if (palette.isEmpty) continue;
      final sim = _calcSimilarity(targetPalette, palette);
      results.add(SimilarWork(work, sim));
    }

    // Sort by similarity (highest first)
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(count).toList();
  }
}

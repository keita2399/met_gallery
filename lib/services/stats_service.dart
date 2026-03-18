import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static const _viewCountKey = 'stats_view_count';
  static const _artistViewsKey = 'stats_artist_views';
  static const _viewedIdsKey = 'stats_viewed_ids';

  /// Record a viewed artwork
  static Future<void> recordView(int artworkId, String artist) async {
    final prefs = await SharedPreferences.getInstance();

    // Total views
    final total = (prefs.getInt(_viewCountKey) ?? 0) + 1;
    await prefs.setInt(_viewCountKey, total);

    // Artist views (stored as "artist:count,artist:count,...")
    final artistMap = _getArtistMap(prefs);
    artistMap[artist] = (artistMap[artist] ?? 0) + 1;
    await prefs.setString(_artistViewsKey, _encodeMap(artistMap));

    // Unique viewed IDs
    final viewedIds = prefs.getStringList(_viewedIdsKey) ?? [];
    final idStr = artworkId.toString();
    if (!viewedIds.contains(idStr)) {
      viewedIds.add(idStr);
      await prefs.setStringList(_viewedIdsKey, viewedIds);
    }
  }

  /// Get total view count
  static Future<int> getTotalViews() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_viewCountKey) ?? 0;
  }

  /// Get unique artwork count
  static Future<int> getUniqueCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_viewedIdsKey) ?? []).length;
  }

  /// Get artist view counts (sorted by count descending)
  static Future<Map<String, int>> getArtistViews() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _getArtistMap(prefs);
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  static Map<String, int> _getArtistMap(SharedPreferences prefs) {
    final str = prefs.getString(_artistViewsKey) ?? '';
    if (str.isEmpty) return {};
    final map = <String, int>{};
    for (final entry in str.split('|')) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        map[parts[0]] = int.tryParse(parts[1]) ?? 0;
      }
    }
    return map;
  }

  static String _encodeMap(Map<String, int> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join('|');
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// ローカルのみのお気に入り管理（Firebase不使用）
class FirestoreService {
  static Future<void> addFavorite(int artworkId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('favorites') ?? []).toSet();
    ids.add(artworkId.toString());
    await prefs.setStringList('favorites', ids.toList());
  }

  static Future<void> removeFavorite(int artworkId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('favorites') ?? []).toSet();
    ids.remove(artworkId.toString());
    await prefs.setStringList('favorites', ids.toList());
  }

  static Future<bool> toggleFavorite(int artworkId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList('favorites') ?? []).toSet();

    if (ids.contains(artworkId.toString())) {
      await removeFavorite(artworkId);
      return false;
    } else {
      await addFavorite(artworkId);
      return true;
    }
  }

  static Future<Set<int>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('favorites') ?? [];
    return ids.map((s) => int.parse(s)).toSet();
  }

  static Future<bool> isFavorite(int artworkId) async {
    final ids = await getFavoriteIds();
    return ids.contains(artworkId);
  }
}

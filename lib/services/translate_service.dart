import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslateService {
  static final Map<String, String> _cache = {};

  /// アーティスト名の翻訳（キャッシュ付き、Google翻訳APIを使用）
  static final Map<String, String> _artistCache = {};

  static String translateArtist(String name) {
    if (_artistCache.containsKey(name)) return _artistCache[name]!;
    // 非同期翻訳をトリガー（結果はキャッシュされ次回から使われる）
    _translateArtistAsync(name);
    return name; // 初回はそのまま返す
  }

  static Future<void> _translateArtistAsync(String name) async {
    if (_artistCache.containsKey(name)) return;
    final translated = await toJapanese(name);
    _artistCache[name] = translated;
  }

  /// アーティスト名を非同期で翻訳して返す
  static Future<String> translateArtistAsync(String name) async {
    if (_artistCache.containsKey(name)) return _artistCache[name]!;
    final translated = await toJapanese(name);
    _artistCache[name] = translated;
    return translated;
  }

  static Future<String> toJapanese(String text) async {
    if (text.trim().isEmpty) return text;

    // Check cache
    if (_cache.containsKey(text)) return _cache[text]!;

    try {
      final encoded = Uri.encodeComponent(text);
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ja&dt=t&q=$encoded',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return text;

      final data = jsonDecode(response.body);
      final sentences = data[0] as List<dynamic>;
      final translated = sentences.map((s) => s[0] as String).join();

      _cache[text] = translated;
      return translated;
    } catch (e) {
      return text;
    }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/art_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/artwork.dart';
import '../config/app_config.dart';
import '../services/art_api.dart';
import '../services/firestore_service.dart';
import '../services/translate_service.dart';
import 'detail_screen.dart';
import 'quiz_screen.dart';

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> with SingleTickerProviderStateMixin {
  List<Artwork> _allWorks = [];
  Artwork? _result;
  bool _loading = true;
  bool _rolling = false;
  bool _alreadyDrawnToday = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  String? _translatedTitle;
  List<Artwork> _history = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('gacha_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final works = await artApi.fetchHighlights(limit: 20);
      setState(() {
        _allWorks = works;
        _loading = false;
      });

      // Load gacha history
      final historyIds = prefs.getStringList('gacha_history') ?? [];
      final historyWorks = <Artwork>[];
      for (final idStr in historyIds.reversed) {
        final id = int.tryParse(idStr);
        if (id != null) {
          final match = works.where((w) => w.id == id).toList();
          if (match.isNotEmpty) historyWorks.add(match.first);
        }
      }
      setState(() => _history = historyWorks);

      if (lastDate == today) {
        final savedId = prefs.getInt('gacha_result');
        if (savedId != null) {
          final saved = works.where((w) => w.id == savedId).toList();
          if (saved.isNotEmpty) {
            setState(() {
              _result = saved.first;
              _alreadyDrawnToday = true;
            });
            _animController.forward();
            _translateResult(saved.first);
          }
        }
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _translateResult(Artwork artwork) async {
    final title = await TranslateService.toJapanese(artwork.title);
    if (mounted) setState(() => _translatedTitle = title);
  }

  Future<void> _drawGacha() async {
    if (_allWorks.isEmpty || _rolling) return;

    setState(() {
      _rolling = true;
      _translatedTitle = null;
    });
    _animController.reset();

    await Future.delayed(const Duration(milliseconds: 800));

    final random = Random();
    final artwork = _allWorks[random.nextInt(_allWorks.length)];

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('gacha_date', today);
    await prefs.setInt('gacha_result', artwork.id);

    // Add to favorites automatically
    await FirestoreService.addFavorite(artwork.id);

    // Save to history
    final historyIds = prefs.getStringList('gacha_history') ?? [];
    if (!historyIds.contains(artwork.id.toString())) {
      historyIds.add(artwork.id.toString());
      await prefs.setStringList('gacha_history', historyIds);
    }

    setState(() {
      _result = artwork;
      _rolling = false;
      _alreadyDrawnToday = true;
      if (!_history.any((h) => h.id == artwork.id)) {
        _history.insert(0, artwork);
      }
    });
    _animController.forward();
    _translateResult(artwork);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '今日の${appConfig.artworkLabel}ガチャ',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '毎日ひとつ、新しい${appConfig.artworkLabel}と出会おう',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
          // クイズボタン（ガチャを引いた後にアニメーション付きで表示）
          AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: _alreadyDrawnToday
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizScreen()));
                        },
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) => Transform.scale(scale: value, child: child),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.quiz, color: Colors.amber, size: 16),
                                SizedBox(width: 6),
                                Text('クイズに挑戦！', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _showHistory = !_showHistory),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showHistory ? Icons.expand_less : Icons.history,
                      color: Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showHistory ? '閉じる' : '過去の記録（${_history.length}作品）',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: _showHistory ? _buildHistory() : (_result != null ? _buildResult() : _buildDrawButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawButton() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_rolling) ...[
            const SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.amber),
            ),
            const SizedBox(height: 24),
            const Text('抽選中...', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ] else ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _drawGacha,
                child: Container(
                  width: 160,
                  height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text('引く', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'タップして今日の${appConfig.artworkLabel}を引こう',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResult() {
    final artwork = _result!;
    return ScaleTransition(
      scale: _scaleAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => DetailScreen(artwork: artwork)),
              );
            },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: artwork.imageUrl != null
                      ? Hero(
                          tag: 'artwork_${artwork.id}',
                          child: ArtImage(
                            imageUrl: artwork.imageUrl!,
                            fit: BoxFit.contain,

                            placeholder: (context, url) => const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => const SizedBox(
                              height: 200,
                              child: Center(child: Icon(Icons.broken_image, color: Colors.white54)),
                            ),
                          ),
                        )
                      : const SizedBox(height: 200),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _translatedTitle ?? artwork.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_translatedTitle != null && _translatedTitle != artwork.title) ...[
                const SizedBox(height: 4),
                Text(
                  artwork.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '${TranslateService.translateArtist(artwork.artist)}  •  ${artwork.date}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _alreadyDrawnToday ? 'コレクションに追加済み！' : '新しい発見！',
                  style: const TextStyle(color: Colors.amber, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'タップで詳細を見る',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
              ),
              const SizedBox(height: 16),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _result = null;
                      _translatedTitle = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'もう一度引く',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final artwork = _history[index];
        final jaArtist = TranslateService.translateArtist(artwork.artist);
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => DetailScreen(artwork: artwork)),
              );
            },
            child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (artwork.imageUrl != null)
                  ArtImage(
                    imageUrl: artwork.imageUrl!,
                    fit: BoxFit.cover,

                    placeholder: (context, url) => Container(color: Colors.grey[900]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.broken_image, color: Colors.white24),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Text(
                    jaArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
}

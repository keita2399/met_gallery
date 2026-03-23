import 'package:flutter/material.dart';
import '../widgets/art_image.dart';
import '../config/app_config.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';
import '../services/bgm_service.dart';
import '../services/firestore_service.dart';
import '../services/translate_service.dart';
import 'detail_screen.dart';
import 'gallery_screen.dart';
import 'favorites_screen.dart';
import '../widgets/install_banner.dart';
import 'gacha_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Artwork? _todayArtwork;
  bool _loading = true;
  String? _error;
  int _currentIndex = 0;
  String? _translatedTitle;
  String? _translatedDescription;
  bool _isFavorite = false;
  bool _bgmPlaying = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _loadTodayArtwork();
  }

  Future<void> _loadTodayArtwork() async {
    try {
      final works = await artApi.fetchHighlights(limit: 1);
      if (works.isEmpty) {
        setState(() { _error = '作品が見つかりません'; _loading = false; });
        return;
      }
      final artwork = works[0];
      if (mounted) {
        setState(() {
          _todayArtwork = artwork;
          _loading = false;
        });
        _fadeController.forward();
        // awaitして未処理rejectionを防ぐ
        await _translateArtwork(artwork);
        final fav = await FirestoreService.isFavorite(artwork.id);
        if (mounted) setState(() => _isFavorite = fav);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _translateArtwork(Artwork artwork) async {
    final title = await TranslateService.toJapanese(artwork.title);
    if (mounted) setState(() => _translatedTitle = title);

    if (artwork.description != null) {
      final desc = await TranslateService.toJapanese(artwork.description!);
      if (mounted) setState(() => _translatedDescription = desc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      _buildHome(),
      const GalleryScreen(),
      const GachaScreen(),
      if (appConfig.hasTimeline) const TimelineScreen(),
      const FavoritesScreen(),
    ];

    final bgmIndex = screens.length; // BGMボタンのインデックス

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: screens[_currentIndex]),
          const InstallBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          // BGMボタン（最後）はトグル再生、画面遷移しない
          if (i == bgmIndex) {
            BgmService.instance.toggle();
            setState(() {});
            return;
          }
          setState(() => _currentIndex = i);
        },
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '今日'),
          const NavigationDestination(icon: Icon(Icons.collections_outlined), selectedIcon: Icon(Icons.collections), label: 'ギャラリー'),
          const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'ガチャ'),
          if (appConfig.hasTimeline)
            const NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: '年表'),
          const NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'コレクション'),
          NavigationDestination(
            icon: Icon(BgmService.instance.isPlaying ? Icons.music_note : Icons.music_off,
              color: BgmService.instance.isPlaying ? Colors.amber : null),
            label: BgmService.instance.isPlaying ? '♪ 再生中' : 'BGM',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildHome() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: appConfig.themeColor),
            const SizedBox(height: 16),
            Text('今日の${appConfig.artworkLabel}を探しています...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(child: Text('エラー: $_error', style: const TextStyle(color: Colors.white)));
    }
    if (_todayArtwork == null) {
      return const Center(child: Text('作品が見つかりません', style: TextStyle(color: Colors.white)));
    }

    final artwork = _todayArtwork!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(fullscreenDialog: true, builder: (_) => DetailScreen(artwork: artwork)),
          );
          final fav = await FirestoreService.isFavorite(artwork.id);
          if (mounted) setState(() => _isFavorite = fav);
        },
        child: Stack(
        fit: StackFit.expand,
        children: [
          if (artwork.imageUrl != null)
            Hero(
              tag: 'artwork_${artwork.id}',
              child: ArtImage(
                imageUrl: artwork.imageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,

                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
              ),
            ),
          // Gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // Top bar
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.palette, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text('今日の${appConfig.artworkLabel}',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconButton(
                      icon: _isFavorite ? Icons.favorite : Icons.favorite_outline,
                      color: _isFavorite ? Colors.redAccent : Colors.white70,
                      onTap: () async {
                        final result = await FirestoreService.toggleFavorite(artwork.id);
                        setState(() => _isFavorite = result);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Bottom info (fade in + slide up)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_translatedTitle != null) ...[
                  Text(
                    _translatedTitle!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artwork.title,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14, fontStyle: FontStyle.italic),
                  ),
                ] else ...[
                  Text(
                    artwork.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${TranslateService.translateArtist(artwork.artist)}  •  ${artwork.date}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                ),
                if (_translatedDescription != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _translatedDescription!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
                  ),
                ] else if (artwork.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    artwork.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.5),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '詳細を見る',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.5), size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    Color? color,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.amber.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.amber.withValues(alpha: 0.5)) : null,
          ),
          child: Icon(icon, color: color ?? Colors.white70, size: 20),
        ),
      ),
    );
  }
}

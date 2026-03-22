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
      final works = await artApi.fetchHighlights(limit: 50);
      if (works.isEmpty) {
        setState(() { _error = '作品が見つかりません'; _loading = false; });
        return;
      }
      final dayIndex = DateTime.now().day % works.length;
      final artwork = works[dayIndex];
      if (mounted) {
        setState(() {
          _todayArtwork = artwork;
          _loading = false;
        });
        _fadeController.forward();
        _translateArtwork(artwork);
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
    final screens = [
      _buildHome(),
      const GalleryScreen(),
      const GachaScreen(),
      const TimelineScreen(),
      const FavoritesScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: screens[_currentIndex]),
          const InstallBanner(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // BGMミニバー（常時表示）
          _buildBgmBar(),
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '今日'),
              NavigationDestination(icon: Icon(Icons.collections_outlined), selectedIcon: Icon(Icons.collections), label: 'ギャラリー'),
              NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'ガチャ'),
              NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: '年表'),
              NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'コレクション'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBgmBar() {
    final playing = BgmService.instance.isPlaying;
    final track = BgmService.instance.currentTrack;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: playing ? Colors.amber.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                await BgmService.instance.toggle();
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: playing ? Colors.amber.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  color: playing ? Colors.amber : Colors.white54,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              playing ? '${track.title} - ${track.composer}' : 'BGM',
              style: TextStyle(
                color: playing ? Colors.white.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (playing) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async { await BgmService.instance.previous(); setState(() {}); },
                child: Icon(Icons.skip_previous, color: Colors.white.withValues(alpha: 0.5), size: 18),
              ),
            ),
            const SizedBox(width: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async { await BgmService.instance.next(); setState(() {}); },
                child: Icon(Icons.skip_next, color: Colors.white.withValues(alpha: 0.5), size: 18),
              ),
            ),
          ],
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
            Text('今日の名画を探しています...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.palette, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text("今日の名画",
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconButton(
                      icon: _bgmPlaying ? Icons.music_note : Icons.music_off,
                      color: _bgmPlaying ? Colors.amber : Colors.white70,
                      isActive: _bgmPlaying,
                      onTap: () {
                        setState(() => _bgmPlaying = !_bgmPlaying);
                        if (_bgmPlaying) {
                          BgmService.instance.play();
                        } else {
                          BgmService.instance.pause();
                        }
                      },
                    ),
                    const SizedBox(width: 8),
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

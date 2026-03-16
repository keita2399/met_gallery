import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';
import '../services/firestore_service.dart';
import '../services/translate_service.dart';
import 'detail_screen.dart';
import 'gallery_screen.dart';
import 'favorites_screen.dart';
import 'gacha_screen.dart';

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
      final works = await ArtApi.fetchImpressionistWorks(limit: 100);
      if (works.isNotEmpty) {
        final dayIndex = DateTime.now().day % works.length;
        setState(() {
          _todayArtwork = works[dayIndex];
          _loading = false;
        });
        _fadeController.forward();
        _translateArtwork(works[dayIndex]);
        final fav = await FirestoreService.isFavorite(works[dayIndex].id);
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
      const FavoritesScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '今日'),
          NavigationDestination(icon: Icon(Icons.collections_outlined), selectedIcon: Icon(Icons.collections), label: 'ギャラリー'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'ガチャ'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'コレクション'),
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
      return const Center(child: CircularProgressIndicator());
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
              child: CachedNetworkImage(
                imageUrl: artwork.imageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                httpHeaders: ArtApi.imageHeaders,
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

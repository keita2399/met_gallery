import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';
import '../services/firestore_service.dart';
import '../services/translate_service.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Artwork> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favSet = await FirestoreService.getFavoriteIds();
    if (favSet.isEmpty) {
      setState(() {
        _favorites = [];
        _loading = false;
      });
      return;
    }

    try {
      final allWorks = await ArtApi.fetchImpressionistWorks(limit: 100);
      setState(() {
        _favorites = allWorks.where((a) => favSet.contains(a.id)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeFavorite(Artwork artwork) async {
    await FirestoreService.removeFavorite(artwork.id);
    setState(() {
      _favorites.removeWhere((a) => a.id == artwork.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'マイコレクション',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                if (_favorites.isNotEmpty)
                  Text(
                    '${_favorites.length}作品',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, color: Colors.white.withValues(alpha: 0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'まだお気に入りがありません',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'ギャラリーでハートをタップして追加しよう',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final artwork = _favorites[index];
        final jaArtist = TranslateService.translateArtist(artwork.artist);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(fullscreenDialog: true, builder: (_) => DetailScreen(artwork: artwork)),
              );
              _loadFavorites();
            },
            onLongPress: () => _showDeleteDialog(artwork),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (artwork.imageUrl != null)
                  Hero(
                    tag: 'artwork_${artwork.id}',
                    child: CachedNetworkImage(
                      imageUrl: artwork.imageUrl!,
                      fit: BoxFit.cover,
                      httpHeaders: ArtApi.imageHeaders,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.broken_image, color: Colors.white24),
                      ),
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
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artwork.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        jaArtist,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    ],
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

  void _showDeleteDialog(Artwork artwork) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        title: const Text('コレクションから削除', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          '「${artwork.title}」をコレクションから削除しますか？',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFavorite(artwork);
            },
            child: const Text('削除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

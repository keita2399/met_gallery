import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';
import '../services/firestore_service.dart';
import '../services/translate_service.dart';
import 'detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  List<Artwork> _artworks = [];
  List<Artwork> _filteredArtworks = [];
  Set<int> _favoriteIds = {};
  bool _loading = true;
  int _currentPage = 0;
  String? _selectedArtist;
  final Map<int, String> _translatedTitles = {};
  bool _panelOpen = false;
  double _pageOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() => _pageOffset = _pageController.page ?? 0.0);
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _favoriteIds = await FirestoreService.getFavoriteIds();

    try {
      final works = await ArtApi.fetchImpressionistWorks(
        limit: 100,
        artistFilter: _selectedArtist,
      );
      setState(() {
        _artworks = works;
        _filteredArtworks = works;
        _loading = false;
        _currentPage = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      if (works.isNotEmpty) {
        _translateTitle(works[0]);
      }
      for (final w in works) {
        _translateTitle(w);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _translateTitle(Artwork artwork) async {
    if (_translatedTitles.containsKey(artwork.id)) return;
    final translated = await TranslateService.toJapanese(artwork.title);
    if (mounted) {
      setState(() => _translatedTitles[artwork.id] = translated);
    }
  }

  Future<void> _toggleFavorite(int id) async {
    final isFav = await FirestoreService.toggleFavorite(id);
    setState(() {
      if (isFav) {
        _favoriteIds.add(id);
      } else {
        _favoriteIds.remove(id);
      }
    });
  }

  void _searchArtworks(String query) {
    if (query.isEmpty) {
      setState(() => _filteredArtworks = _artworks);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredArtworks = _artworks.where((a) {
        final jaArtist = TranslateService.translateArtist(a.artist).toLowerCase();
        final jaTitle = (_translatedTitles[a.id] ?? '').toLowerCase();
        return a.title.toLowerCase().contains(lower) ||
            a.artist.toLowerCase().contains(lower) ||
            jaArtist.contains(lower) ||
            jaTitle.contains(lower) ||
            a.date.toLowerCase().contains(lower);
      }).toList();
    });
  }

  void _selectArtwork(Artwork artwork) {
    final index = _artworks.indexOf(artwork);
    if (index >= 0 && _pageController.hasClients) {
      _pageController.jumpToPage(index);
      setState(() => _currentPage = index);
      _translateTitle(artwork);
    }
  }

  void _showArtistFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a1a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('画家で絞り込み', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _filterChip('すべての画家', null),
              ...ArtApi.impressionistArtists.map((a) => _filterChip(TranslateService.translateArtist(a), a)),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, String? artist) {
    final selected = _selectedArtist == artist;
    return ListTile(
      title: Text(label, style: TextStyle(color: selected ? Colors.amber : Colors.white70)),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Colors.amber : Colors.white30,
      ),
      onTap: () {
        Navigator.pop(context);
        if (_selectedArtist != artist) {
          _selectedArtist = artist;
          _loadData();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_artworks.isEmpty) {
      return const Center(child: Text('作品が見つかりません', style: TextStyle(color: Colors.white)));
    }

    return Row(
      children: [
        // Left: Main artwork area
        Expanded(
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _artworks.length,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _translateTitle(_artworks[i]);
                  if (i + 1 < _artworks.length) {
                    _translateTitle(_artworks[i + 1]);
                  }
                },
                itemBuilder: (context, index) => _buildArtworkPage(_artworks[index], index),
              ),
              // Top bar
              Positioned(
                top: 50,
                left: 24,
                right: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${_artworks.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                    Row(
                      children: [
                        _iconButton(
                          icon: Icons.search,
                          isActive: _panelOpen,
                          onTap: () => setState(() {
                            _panelOpen = !_panelOpen;
                            if (!_panelOpen) {
                              _searchController.clear();
                              _filteredArtworks = _artworks;
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                          onTap: _showArtistFilter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedArtist != null
                                  ? Colors.amber.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: _selectedArtist != null
                                  ? Border.all(color: Colors.amber.withValues(alpha: 0.5))
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.filter_list, color: Colors.white70, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedArtist != null ? TranslateService.translateArtist(_selectedArtist!) : 'すべて',
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right: Artwork list panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: _panelOpen ? 280 : 0,
          child: _panelOpen
              ? Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    border: Border(
                      left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '作品一覧',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_filteredArtworks.length}作品',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Search field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: '検索...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                            prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        _searchArtworks('');
                                      },
                                      child: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.3), size: 16),
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: _searchArtworks,
                        ),
                      ),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _filteredArtworks.length,
                          itemBuilder: (context, index) {
                            final w = _filteredArtworks[index];
                            final isSelected = _currentPage < _artworks.length && w.id == _artworks[_currentPage].id;
                            final jaTitle = _translatedTitles[w.id];
                            final jaArtist = TranslateService.translateArtist(w.artist);

                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                              onTap: () => _selectArtwork(w),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.amber.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(color: Colors.amber.withValues(alpha: 0.3))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: w.imageUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: w.imageUrl!,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              httpHeaders: ArtApi.imageHeaders,
                                              errorWidget: (context, url, error) => Container(
                                                width: 44, height: 44,
                                                color: Colors.grey[900],
                                              ),
                                            )
                                          : Container(
                                              width: 44, height: 44,
                                              color: Colors.grey[900],
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            jaTitle ?? w.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isSelected ? Colors.amber : Colors.white,
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            jaArtist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.play_arrow, color: Colors.amber.withValues(alpha: 0.6), size: 16),
                                  ],
                                ),
                              ),
                            ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildArtworkPage(Artwork artwork, int index) {
    final isFav = _favoriteIds.contains(artwork.id);
    final translatedTitle = _translatedTitles[artwork.id];
    final isMobile = MediaQuery.of(context).size.width < 600;

    final favButton = _sideButton(
      icon: isFav ? Icons.favorite : Icons.favorite_outline,
      color: isFav ? Colors.redAccent : Colors.white,
      label: isFav ? '保存済' : '保存',
      onTap: () => _toggleFavorite(artwork.id),
      compact: isMobile,
    );
    final shareButton = _sideButton(
      icon: Icons.share_outlined,
      color: Colors.white,
      label: 'シェア',
      onTap: () {
        final jaArtist = TranslateService.translateArtist(artwork.artist);
        final jaTitle = translatedTitle ?? artwork.title;
        SharePlus.instance.share(
          ShareParams(
            text: '$jaTitle\n$jaArtist（${artwork.date}）\n\nhttps://www.artic.edu/artworks/${artwork.id}',
          ),
        );
      },
      compact: isMobile,
    );
    final detailButton = _sideButton(
      icon: Icons.info_outline,
      color: Colors.white,
      label: '詳細',
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => DetailScreen(artwork: artwork)),
        );
        final favIds = await FirestoreService.getFavoriteIds();
        if (mounted) setState(() => _favoriteIds = favIds);
      },
      compact: isMobile,
    );

    return Stack(
        fit: StackFit.expand,
        children: [
          if (artwork.imageUrl != null)
            Transform.translate(
              offset: Offset(0, (index - _pageOffset) * 60),
              child: Hero(
                tag: 'artwork_${artwork.id}',
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: CachedNetworkImage(
                    imageUrl: artwork.imageUrl!,
                    fit: BoxFit.contain,
                    httpHeaders: ArtApi.imageHeaders,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
                  ),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          if (!isMobile)
            // PC: Right side buttons
            Positioned(
              right: 48,
              bottom: 120,
              child: Column(
                children: [
                  favButton,
                  const SizedBox(height: 24),
                  shareButton,
                  const SizedBox(height: 24),
                  detailButton,
                ],
              ),
            ),
          // Bottom info
          Positioned(
            bottom: isMobile ? 80 : 24,
            left: 24,
            right: isMobile ? 24 : 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (translatedTitle != null) ...[
                  Text(
                    translatedTitle,
                    style: TextStyle(color: Colors.white, fontSize: _panelOpen ? 16 : (isMobile ? 18 : 20), fontWeight: FontWeight.bold, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artwork.title,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: _panelOpen ? 10 : 12, fontStyle: FontStyle.italic),
                  ),
                ] else ...[
                  Text(
                    artwork.title,
                    style: TextStyle(color: Colors.white, fontSize: _panelOpen ? 16 : (isMobile ? 18 : 20), fontWeight: FontWeight.bold, height: 1.2),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${TranslateService.translateArtist(artwork.artist)}  •  ${artwork.date}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: _panelOpen ? 11 : 13),
                ),
              ],
            ),
          ),
          if (isMobile)
            // Mobile: Bottom action bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [favButton, shareButton, detailButton],
                ),
              ),
            ),
        ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.amber.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.amber.withValues(alpha: 0.5)) : null,
          ),
          child: Icon(icon, color: Colors.white70, size: 22),
        ),
      ),
    );
  }

  Widget _sideButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: compact ? 22 : 28),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white70, fontSize: compact ? 10 : 12)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

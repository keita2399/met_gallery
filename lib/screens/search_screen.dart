import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';
import '../services/translate_service.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Artwork> _allWorks = [];
  List<Artwork> _results = [];
  bool _loading = true;
  final Map<int, String> _translatedTitles = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final works = await ArtApi.fetchImpressionistWorks(limit: 100);
      setState(() {
        _allWorks = works;
        _results = works;
        _loading = false;
      });
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

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _results = _allWorks);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _results = _allWorks.where((a) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: '作品名・画家名で検索...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  )
                : null,
          ),
          onChanged: _search,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    '「${_controller.text}」に一致する作品はありません',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final artwork = _results[index];
                    final jaTitle = _translatedTitles[artwork.id];
                    final jaArtist = TranslateService.translateArtist(artwork.artist);

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: artwork.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: artwork.imageUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                httpHeaders: ArtApi.imageHeaders,
                                errorWidget: (context, url, error) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.broken_image, color: Colors.white24, size: 24),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[900],
                              ),
                      ),
                      title: Text(
                        jaTitle ?? artwork.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '$jaArtist  •  ${artwork.date}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(fullscreenDialog: true, builder: (_) => DetailScreen(artwork: artwork)),
                        );
                      },
                    ));
                  },
                ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

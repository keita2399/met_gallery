import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';
import '../services/translate_service.dart';
import '../widgets/light_simulation_widget.dart';

class DetailScreen extends StatefulWidget {
  final Artwork artwork;

  const DetailScreen({super.key, required this.artwork});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Artwork? _detail;
  bool _loading = true;
  String? _translatedDescription;
  String? _translatedTitle;
  String? _translatedMedium;
  String? _translatedOrigin;
  String? _translatedCredit;
  bool _translating = false;
  bool _lightSimulation = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final detail = await ArtApi.fetchArtworkDetail(widget.artwork.id);
    setState(() {
      _detail = detail ?? widget.artwork;
      _loading = false;
    });
    _translateContent();
  }

  Future<void> _translateContent() async {
    final artwork = _detail ?? widget.artwork;
    setState(() => _translating = true);

    try {
      final futures = <Future>[];

      futures.add(
        TranslateService.toJapanese(artwork.title).then((t) {
          if (mounted) setState(() => _translatedTitle = t);
        }),
      );

      if (artwork.description != null) {
        final cleanDesc = artwork.description!.replaceAll(RegExp(r'<[^>]*>'), '');
        futures.add(
          TranslateService.toJapanese(cleanDesc).then((t) {
            if (mounted) setState(() => _translatedDescription = t);
          }),
        );
      }

      if (artwork.medium != null) {
        futures.add(
          TranslateService.toJapanese(artwork.medium!).then((t) {
            if (mounted) setState(() => _translatedMedium = t);
          }),
        );
      }

      if (artwork.placeOfOrigin != null) {
        futures.add(
          TranslateService.toJapanese(artwork.placeOfOrigin!).then((t) {
            if (mounted) setState(() => _translatedOrigin = t);
          }),
        );
      }

      if (artwork.creditLine != null) {
        futures.add(
          TranslateService.toJapanese(artwork.creditLine!).then((t) {
            if (mounted) setState(() => _translatedCredit = t);
          }),
        );
      }

      await Future.wait(futures);
    } catch (_) {}

    if (mounted) setState(() => _translating = false);
  }

  void _enterZoom() {
    final artwork = _detail ?? widget.artwork;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenZoomPage(artwork: artwork);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scale = Tween<double>(begin: 0.85, end: 1.0)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 550),
      ),
    );
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final artwork = _detail ?? widget.artwork;
    final jaArtist = TranslateService.translateArtist(artwork.artist);
    final isMobile = _isMobile;

    // Light simulation mode (native only)
    if (_lightSimulation && artwork.imageUrl != null) {
      return LightSimulationWidget(
        imageUrl: artwork.imageUrl!,
        onClose: () => setState(() => _lightSimulation = false),
      );
    }

    // Normal detail view
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * (isMobile ? 0.4 : 0.5),
                pinned: true,
                backgroundColor: Colors.black,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: artwork.imageUrl != null
                      ? MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _enterZoom,
                            child: Hero(
                              tag: 'artwork_${artwork.id}',
                              child: CachedNetworkImage(
                                imageUrl: artwork.imageUrlHigh ?? artwork.imageUrl!,
                                fit: BoxFit.contain,
                                httpHeaders: ArtApi.imageHeaders,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, isMobile ? 80 : 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      if (_translatedTitle != null) ...[
                        Text(
                          _translatedTitle!,
                          style: TextStyle(color: Colors.white, fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold, height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artwork.title,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: isMobile ? 12 : 14, fontStyle: FontStyle.italic),
                        ),
                      ] else ...[
                        Text(
                          artwork.title,
                          style: TextStyle(color: Colors.white, fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold, height: 1.3),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Artist & Date
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(jaArtist, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                if (jaArtist != artwork.artist)
                                  Text(artwork.artist, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(artwork.date, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ),
                        ],
                      ),
                      // Description
                      if (artwork.description != null) ...[
                        const SizedBox(height: 24),
                        if (_translatedDescription != null)
                          Text(
                            _translatedDescription!,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15, height: 1.7),
                          )
                        else if (_translating)
                          Row(
                            children: [
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text('翻訳中...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                            ],
                          )
                        else
                          _removeHtmlTags(artwork.description!),
                      ],
                      if (_loading) ...[
                        const SizedBox(height: 24),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      if (!_loading) ...[
                        if (artwork.medium != null) ...[
                          const SizedBox(height: 24),
                          _infoRow('技法・素材', _translatedMedium ?? artwork.medium!),
                        ],
                        if (artwork.dimensions != null) ...[
                          const SizedBox(height: 12),
                          _infoRow('サイズ', artwork.dimensions!),
                        ],
                        if (artwork.placeOfOrigin != null) ...[
                          const SizedBox(height: 12),
                          _infoRow('制作地', _translatedOrigin ?? artwork.placeOfOrigin!),
                        ],
                        if (artwork.creditLine != null) ...[
                          const SizedBox(height: 12),
                          _infoRow('所蔵', _translatedCredit ?? artwork.creditLine!),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isMobile) ...[
            // Mobile: Top close button
            Positioned(
              top: 16,
              right: 16,
              child: _actionButton(icon: Icons.close, label: '', onTap: () => Navigator.pop(context), compact: true),
            ),
            // Mobile: Bottom action bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _actionButton(
                      icon: Icons.share_outlined,
                      label: 'シェア',
                      onTap: () {
                        final jaTitle = _translatedTitle ?? artwork.title;
                        SharePlus.instance.share(
                          ShareParams(
                            text: '$jaTitle\n$jaArtist（${artwork.date}）\n\nhttps://www.artic.edu/artworks/${artwork.id}',
                          ),
                        );
                      },
                      compact: true,
                    ),
                    _actionButton(icon: Icons.zoom_in, label: '拡大', onTap: _enterZoom, compact: true),
                    _actionButton(
                      icon: Icons.wb_sunny_outlined,
                      label: '光',
                      onTap: () => setState(() => _lightSimulation = true),
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // PC: Right side buttons
            Positioned(
              top: 50,
              right: 40,
              child: Column(
                children: [
                  _actionButton(
                    icon: Icons.close,
                    label: '閉じる',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 16),
                  _actionButton(
                    icon: Icons.share_outlined,
                    label: 'シェア',
                    onTap: () {
                      final jaTitle = _translatedTitle ?? artwork.title;
                      SharePlus.instance.share(
                        ShareParams(
                          text: '$jaTitle\n$jaArtist（${artwork.date}）\n\nhttps://www.artic.edu/artworks/${artwork.id}',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _actionButton(
                    icon: Icons.zoom_in,
                    label: '拡大',
                    onTap: _enterZoom,
                  ),
                  const SizedBox(height: 16),
                  _actionButton(
                    icon: Icons.wb_sunny_outlined,
                    label: '光',
                    onTap: () => setState(() => _lightSimulation = true),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    bool compact = false,
  }) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: enabled ? Colors.white : Colors.white30, size: compact ? 20 : 22),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white24,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _removeHtmlTags(String html) {
    final text = html.replaceAll(RegExp(r'<[^>]*>'), '');
    return Text(
      text,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15, height: 1.7),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.4)),
      ],
    );
  }

}

/// Fullscreen zoom page with fade transition
class _FullscreenZoomPage extends StatefulWidget {
  final Artwork artwork;
  const _FullscreenZoomPage({required this.artwork});

  @override
  State<_FullscreenZoomPage> createState() => _FullscreenZoomPageState();
}

class _FullscreenZoomPageState extends State<_FullscreenZoomPage>
    with TickerProviderStateMixin {
  final TransformationController _zoomController = TransformationController();
  double _currentScale = 1.0;
  AnimationController? _scaleAnimController;
  AnimationController? _fadeAnimController;
  double _opacity = 1.0;

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  void _animateToScale(double targetScale) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    targetScale = targetScale.clamp(1.0, 8.0);
    if (targetScale == _currentScale) return;

    final startMatrix = _zoomController.value.clone();
    final endMatrix = Matrix4.identity();
    endMatrix.storage[0] = targetScale;
    endMatrix.storage[5] = targetScale;
    endMatrix.storage[12] = cx - cx * targetScale;
    endMatrix.storage[13] = cy - cy * targetScale;

    // Scale animation
    _scaleAnimController?.dispose();
    _scaleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final curve = CurvedAnimation(parent: _scaleAnimController!, curve: Curves.easeInOutCubic);
    curve.addListener(() {
      final t = curve.value;
      final m = Matrix4.identity();
      for (int i = 0; i < 16; i++) {
        m.storage[i] = startMatrix.storage[i] + (endMatrix.storage[i] - startMatrix.storage[i]) * t;
      }
      _zoomController.value = m;
    });

    // Fade pulse: 1.0 → 0.82 → 1.0 (breathe effect)
    _fadeAnimController?.dispose();
    _fadeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimController!.addListener(() {
      final t = _fadeAnimController!.value;
      // Sine curve: dips to 0.82 at midpoint, returns to 1.0
      setState(() {
        _opacity = 1.0 - 0.18 * sin(t * pi);
      });
    });

    _scaleAnimController!.forward();
    _fadeAnimController!.forward();
    _currentScale = targetScale;
    setState(() {});
  }

  void _zoomIn() => _animateToScale(_currentScale * 1.5);
  void _zoomOut() => _animateToScale(_currentScale / 1.5);

  @override
  Widget build(BuildContext context) {
    final artwork = widget.artwork;
    final isMobile = _isMobile;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: _opacity,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: InteractiveViewer(
                transformationController: _zoomController,
                minScale: 1.0,
                maxScale: 8.0,
                panEnabled: true,
                onInteractionEnd: (details) {
                  final scale = _zoomController.value.getMaxScaleOnAxis();
                  setState(() => _currentScale = scale);
                },
                child: CachedNetworkImage(
                  imageUrl: artwork.imageUrlHigh ?? artwork.imageUrl!,
                  fit: BoxFit.contain,
                  httpHeaders: ArtApi.imageHeaders,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 64)),
                ),
              ),
            ),
            ),
          ),
          if (_currentScale > 1.0)
            Positioned(
              top: isMobile ? 16 : 50,
              left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentScale.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          if (isMobile) ...[
            Positioned(
              top: 16,
              right: 16,
              child: _actionButton(icon: Icons.close, label: '', onTap: () => Navigator.pop(context), compact: true),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _actionButton(icon: Icons.zoom_out, label: '縮小', onTap: _zoomOut, enabled: _currentScale > 1.0, compact: true),
                    const SizedBox(width: 32),
                    _actionButton(icon: Icons.zoom_in, label: '拡大', onTap: _zoomIn, compact: true),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'ピンチで拡大縮小・ドラッグで移動',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: 50,
              right: 40,
              child: Column(
                children: [
                  _actionButton(icon: Icons.close, label: '戻る', onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 16),
                  _actionButton(icon: Icons.zoom_in, label: '拡大', onTap: _zoomIn),
                  const SizedBox(height: 16),
                  _actionButton(icon: Icons.zoom_out, label: '縮小', onTap: _zoomOut, enabled: _currentScale > 1.0),
                ],
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'ドラッグで移動・ホイールで拡大縮小',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    bool compact = false,
  }) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 8 : 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: enabled ? Colors.white : Colors.white30, size: compact ? 20 : 22),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white70 : Colors.white24,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scaleAnimController?.dispose();
    _fadeAnimController?.dispose();
    _zoomController.dispose();
    super.dispose();
  }
}

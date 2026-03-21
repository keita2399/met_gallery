import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/art_api.dart';

/// Light simulation widget using Fragment Shader
class LightSimulationWidget extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onClose;
  final dynamic artwork;
  final double initialScale;

  const LightSimulationWidget({
    super.key,
    required this.imageUrl,
    required this.onClose,
    this.artwork,
    this.initialScale = 1.0,
  });

  @override
  State<LightSimulationWidget> createState() => _LightSimulationWidgetState();
}

class _LightSimulationWidgetState extends State<LightSimulationWidget>
    with TickerProviderStateMixin {
  ui.FragmentShader? _shader;
  ui.Image? _image;
  bool _loading = true;
  String? _error;

  // Multiple light sources (up to 3)
  final List<Offset> _lightPositions = [const Offset(0.5, 0.3)];
  final List<double> _lightIntensities = [0.8];
  int _activeLightIndex = 0;

  // Notifier: triggers CustomPaint repaint without rebuilding InteractiveViewer
  final ValueNotifier<int> _lightNotifier = ValueNotifier<int>(0);
  void _notifyLightChange() => _lightNotifier.value++;

  // Shared light parameters
  double _lightRadius = 0.8;
  double _ambient = 0.3;
  bool _showControls = true;

  // Zoom
  final TransformationController _zoomController = TransformationController();
  double _currentScale = 1.0;
  bool _showIntro = true;
  bool _userTouched = false;

  // Color temperature presets
  int _colorPresetIndex = 0;
  static const _colorPresets = <_ColorPreset>[
    _ColorPreset('ろうそく', Color(0xFFFFD2A0), 1.0, 0.95, 0.75),
    _ColorPreset('暖色', Color(0xFFFFF0D6), 1.0, 0.95, 0.85),
    _ColorPreset('自然光', Color(0xFFFFFFF0), 1.0, 1.0, 0.96),
    _ColorPreset('昼白色', Color(0xFFE8F0FF), 0.92, 0.95, 1.0),
    _ColorPreset('月明かり', Color(0xFFD0D8FF), 0.85, 0.88, 1.0),
  ];

  // Auto-demo animation
  AnimationController? _demoController;
  // Intro fade animation
  AnimationController? _introFadeController;

  // Flicker (candle) effect
  bool _flickerEnabled = false;
  AnimationController? _flickerController;

  // Frame shadow
  bool _frameShadowEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadResources();
    if (widget.initialScale > 1.0) {
      _currentScale = widget.initialScale;
      // Apply initial zoom after first frame (need screen size)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final size = MediaQuery.of(context).size;
        final cx = size.width / 2;
        final cy = size.height / 2;
        final m = Matrix4.identity();
        m.storage[0] = _currentScale;
        m.storage[5] = _currentScale;
        m.storage[12] = cx - cx * _currentScale;
        m.storage[13] = cy - cy * _currentScale;
        _zoomController.value = m;
      });
    }
  }

  void _startDemo() {
    _demoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        if (!_userTouched && mounted) {
          final t = _demoController!.value * 2 * pi;
          setState(() {
            _lightPositions[0] = Offset(
              0.5 + 0.25 * cos(t),
              0.4 + 0.15 * sin(t),
            );
          });
        }
      });
    _demoController!.repeat();

    _introFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showIntro) {
        _introFadeController!.forward().then((_) {
          if (mounted) setState(() => _showIntro = false);
        });
      }
    });
  }

  void _onUserTouch(Offset localPos, Size boxSize) {
    if (!_userTouched) {
      _userTouched = true;
      _demoController?.stop();
      setState(() => _showIntro = false);
      return; // First touch: just show controls, don't move light yet
    }
    _lightPositions[_activeLightIndex] = Offset(
      (localPos.dx / boxSize.width).clamp(0.0, 1.0),
      (localPos.dy / boxSize.height).clamp(0.0, 1.0),
    );
    _notifyLightChange(); // Repaint only CustomPaint, not InteractiveViewer
  }

  // Light indicator colors (one per light source)
  static const _lightIndicatorColors = [Colors.amber, Colors.cyanAccent, Colors.pinkAccent];
  Color _lightColor(int index) => _lightIndicatorColors[index % _lightIndicatorColors.length];

  // --- Multiple light management ---

  void _addLight() {
    if (_lightPositions.length >= 3) return;
    final offsets = [
      const Offset(0.5, 0.3),
      const Offset(0.3, 0.6),
      const Offset(0.7, 0.6),
    ];
    final idx = _lightPositions.length;
    _lightPositions.add(offsets[idx]);
    _lightIntensities.add(0.5);
    _activeLightIndex = idx;
    setState(() {});
  }

  void _removeActiveLight() {
    if (_lightPositions.length <= 1) return;
    _lightPositions.removeAt(_activeLightIndex);
    _lightIntensities.removeAt(_activeLightIndex);
    if (_activeLightIndex >= _lightPositions.length) {
      _activeLightIndex = _lightPositions.length - 1;
    }
    setState(() {});
  }

  // --- Flicker effect ---

  void _toggleFlicker() {
    _flickerEnabled = !_flickerEnabled;
    if (_flickerEnabled) {
      _flickerController ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10),
      )..addListener(() {
          if (mounted) setState(() {});
        });
      _flickerController!.repeat();
    } else {
      _flickerController?.stop();
    }
    setState(() {});
  }

  double get _flickerValue {
    if (!_flickerEnabled || _flickerController == null || !_flickerController!.isAnimating) {
      return 1.0;
    }
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    return 1.0 +
        0.04 * sin(t * 18.85) +
        0.03 * sin(t * 43.98) +
        0.05 * sin(t * 9.42) +
        0.02 * sin(t * 69.12);
  }

  Future<void> _loadResources() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/lighting.frag');
      _shader = program.fragmentShader();

      _image = await _loadImage(widget.imageUrl);

      if (mounted) {
        setState(() => _loading = false);
        _startDemo();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Load image as ui.Image, with Web-compatible fallback
  Future<ui.Image> _loadImage(String url) async {
    if (kIsWeb) {
      // On Web, fetch bytes via http (avoids CORS/header issues with NetworkImage)
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Image fetch failed: ${response.statusCode}');
      }
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } else {
      // On native, use NetworkImage with custom headers
      final completer = Completer<ui.Image>();
      final imageProvider = NetworkImage(url, headers: artApi.imageHeaders);
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          completer.complete(info.image.clone());
          stream.removeListener(listener);
        },
        onError: (error, _) {
          if (!completer.isCompleted) completer.completeError(error);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return completer.future;
    }
  }

  /// Calculate the painting area bounds (letterboxed within screen)
  Rect _paintingBounds(Size screenSize) {
    if (_image == null) return Rect.zero;
    final imageAspect = _image!.width / _image!.height;
    final canvasAspect = screenSize.width / screenSize.height;
    double dw, dh, ox, oy;
    if (imageAspect > canvasAspect) {
      dw = screenSize.width;
      dh = screenSize.width / imageAspect;
      ox = 0;
      oy = (screenSize.height - dh) / 2;
    } else {
      dh = screenSize.height;
      dw = screenSize.height * imageAspect;
      ox = (screenSize.width - dw) / 2;
      oy = 0;
    }
    return Rect.fromLTWH(ox, oy, dw, dh);
  }

  @override
  void dispose() {
    _lightNotifier.dispose();
    _zoomController.dispose();
    _shader?.dispose();
    _image?.dispose();
    _demoController?.dispose();
    _introFadeController?.dispose();
    _flickerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('光シミュレーションを準備中...',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_error != null || _shader == null || _image == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text('読み込みに失敗しました',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: widget.onClose,
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Canvas: InteractiveViewer for zoom, Listener for light tap
          _JsonLightTapDetector(
            onLightTap: (localPos) {
              final box = context.findRenderObject() as RenderBox;
              _onUserTouch(localPos, box.size);
            },
            child: InteractiveViewer(
              transformationController: _zoomController,
              minScale: 1.0,
              maxScale: 5.0,
              onInteractionEnd: (details) {
                _currentScale = _zoomController.value.getMaxScaleOnAxis();
                setState(() {});
              },
              child: ValueListenableBuilder<int>(
                valueListenable: _lightNotifier,
                builder: (context, _, __) => CustomPaint(
                  painter: _LightingPainter(
                    shader: _shader!,
                    image: _image!,
                    lightPositions: List.unmodifiable(_lightPositions),
                    lightIntensities: List.unmodifiable(_lightIntensities),
                    numLights: _lightPositions.length,
                    lightRadius: _lightRadius,
                    ambient: _ambient,
                    lightColor: _colorPresets[_colorPresetIndex],
                    flicker: _flickerValue,
                    frameShadow: _frameShadowEnabled,
                  ),
                ),
              ),
          ),
          ),

          // Frame overlay (visible ornate frame around the painting)
          if (_frameShadowEnabled && _image != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _FramePainter(
                    paintingBounds: _paintingBounds(screenSize),
                    lightPos: _lightPositions[0],
                    screenSize: screenSize,
                  ),
                ),
              ),
            ),

          // Light position indicators (color-coded per light)
          for (int i = 0; i < _lightPositions.length; i++)
            Positioned(
              left: _lightPositions[i].dx * screenSize.width - 16,
              top: _lightPositions[i].dy * screenSize.height - 16,
              child: IgnorePointer(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _lightColor(i).withValues(alpha: i == _activeLightIndex ? 0.7 : 0.4),
                      width: i == _activeLightIndex ? 2.5 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _lightColor(i).withValues(alpha: i == _activeLightIndex ? 0.8 : 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Intro overlay
          if (_showIntro)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _introFadeController ?? const AlwaysStoppedAnimation(0),
                builder: (context, child) {
                  final opacity = 1.0 - (_introFadeController?.value ?? 0.0);
                  return Opacity(
                    opacity: opacity,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app,
                                color: Colors.white.withValues(alpha: 0.8), size: 48),
                            const SizedBox(height: 16),
                            Text(
                              '画面をなぞると\n光の位置が変わります',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Top-right: close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: _controlButton(
              icon: Icons.close,
              label: '戻る',
              onTap: widget.onClose,
            ),
          ),

          // Zoom indicator
          if (_currentScale > 1.1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _zoomController.value = Matrix4.identity();
                  _currentScale = 1.0;
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentScale.toStringAsFixed(1)}x  ✕',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ),
              ),
            ),

          // Settings toggle (top-left)
          if (_userTouched)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: _controlButton(
                icon: Icons.tune,
                label: '調整',
                onTap: () => setState(() => _showControls = !_showControls),
              ),
            ),

          // Control panel (bottom)
          if (_showControls && _userTouched)
            Positioned(
              bottom: 20,
              left: 24,
              right: 24,
              child: _buildControlPanel(),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return GestureDetector(
      // Absorb all touch events so they don't reach the canvas
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {},
      onTapUp: (_) {},
      onPanStart: (_) {},
      onPanUpdate: (_) {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color temperature presets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_colorPresets.length, (i) {
                final preset = _colorPresets[i];
                final selected = i == _colorPresetIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _colorPresetIndex = i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: preset.displayColor,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.white24,
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.label,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white38,
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Light management row + feature toggles
            Row(
              children: [
                // Light selector buttons
                for (int i = 0; i < _lightPositions.length; i++) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _activeLightIndex = i),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _activeLightIndex
                            ? Colors.amber.withValues(alpha: 0.3)
                            : Colors.transparent,
                        border: Border.all(
                          color: i == _activeLightIndex ? Colors.amber : Colors.white24,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: i == _activeLightIndex ? Colors.amber : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Add light button
                if (_lightPositions.length < 3)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _addLight,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Center(
                        child: Icon(Icons.add, color: Colors.white38, size: 16),
                      ),
                    ),
                  ),
                // Remove light button
                if (_lightPositions.length > 1) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _removeActiveLight,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Center(
                        child: Icon(Icons.remove, color: Colors.white38, size: 16),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Flicker toggle
                _toggleButton(
                  icon: Icons.local_fire_department,
                  label: 'ゆらぎ',
                  isActive: _flickerEnabled,
                  onTap: _toggleFlicker,
                ),
                const SizedBox(width: 8),
                // Frame shadow toggle
                _toggleButton(
                  icon: Icons.crop_square,
                  label: '額縁',
                  isActive: _frameShadowEnabled,
                  onTap: () => setState(() => _frameShadowEnabled = !_frameShadowEnabled),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sliders
            _sliderRow(
              label: '光の強さ',
              icon: Icons.wb_sunny_outlined,
              value: _lightIntensities[_activeLightIndex],
              min: 0.0,
              max: 1.5,
              onChanged: (v) => setState(() => _lightIntensities[_activeLightIndex] = v),
            ),
            const SizedBox(height: 4),
            _sliderRow(
              label: '光の広がり',
              icon: Icons.blur_on,
              value: _lightRadius,
              min: 0.2,
              max: 2.0,
              onChanged: (v) => setState(() => _lightRadius = v),
            ),
            const SizedBox(height: 4),
            _sliderRow(
              label: '周りの明るさ',
              icon: Icons.brightness_low,
              value: _ambient,
              min: 0.0,
              max: 1.0,
              onChanged: (v) => setState(() => _ambient = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.amber.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? Colors.amber.withValues(alpha: 0.5) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? Colors.amber : Colors.white38, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.amber : Colors.white38,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: Colors.white.withValues(alpha: 0.6),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      // HitTestBehavior.opaque ensures the entire button area (including padding)
      // absorbs hits, preventing them from reaching the canvas behind.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter that applies the lighting fragment shader
class _LightingPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image image;
  final List<Offset> lightPositions;
  final List<double> lightIntensities;
  final int numLights;
  final double lightRadius;
  final double ambient;
  final _ColorPreset lightColor;
  final double flicker;
  final bool frameShadow;

  _LightingPainter({
    required this.shader,
    required this.image,
    required this.lightPositions,
    required this.lightIntensities,
    required this.numLights,
    required this.lightRadius,
    required this.ambient,
    required this.lightColor,
    required this.flicker,
    required this.frameShadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imageAspect = image.width / image.height;
    final canvasAspect = size.width / size.height;

    double drawWidth, drawHeight, offsetX, offsetY;
    if (imageAspect > canvasAspect) {
      drawWidth = size.width;
      drawHeight = size.width / imageAspect;
      offsetX = 0;
      offsetY = (size.height - drawHeight) / 2;
    } else {
      drawHeight = size.height;
      drawWidth = size.height * imageAspect;
      offsetX = (size.width - drawWidth) / 2;
      offsetY = 0;
    }

    // Convert screen-space light position to local drawing area
    Offset toLocal(Offset screenPos) {
      return Offset(
        (screenPos.dx * size.width - offsetX) / drawWidth,
        (screenPos.dy * size.height - offsetY) / drawHeight,
      );
    }

    shader.setFloat(0, drawWidth);
    shader.setFloat(1, drawHeight);

    // Light 1
    final l1 = toLocal(lightPositions[0]);
    shader.setFloat(2, l1.dx);
    shader.setFloat(3, l1.dy);
    shader.setFloat(4, lightRadius);
    shader.setFloat(5, ambient);
    shader.setFloat(6, lightIntensities[0]);
    shader.setFloat(7, lightColor.r);
    shader.setFloat(8, lightColor.g);
    shader.setFloat(9, lightColor.b);

    // Light 2
    if (numLights >= 2) {
      final l2 = toLocal(lightPositions[1]);
      shader.setFloat(10, l2.dx);
      shader.setFloat(11, l2.dy);
      shader.setFloat(12, lightIntensities[1]);
    } else {
      shader.setFloat(10, 0.0);
      shader.setFloat(11, 0.0);
      shader.setFloat(12, 0.0);
    }

    // Light 3
    if (numLights >= 3) {
      final l3 = toLocal(lightPositions[2]);
      shader.setFloat(13, l3.dx);
      shader.setFloat(14, l3.dy);
      shader.setFloat(15, lightIntensities[2]);
    } else {
      shader.setFloat(13, 0.0);
      shader.setFloat(14, 0.0);
      shader.setFloat(15, 0.0);
    }

    shader.setFloat(16, flicker);
    shader.setFloat(17, frameShadow ? 1.0 : 0.0);
    shader.setFloat(18, numLights.toDouble());

    shader.setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.drawRect(Rect.fromLTWH(0, 0, drawWidth, drawHeight), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LightingPainter oldDelegate) {
    // Always repaint when flickering
    if (flicker != 1.0 || oldDelegate.flicker != 1.0) return true;
    return numLights != oldDelegate.numLights ||
        lightRadius != oldDelegate.lightRadius ||
        ambient != oldDelegate.ambient ||
        lightColor != oldDelegate.lightColor ||
        frameShadow != oldDelegate.frameShadow ||
        image != oldDelegate.image ||
        !listEquals(lightPositions, oldDelegate.lightPositions) ||
        !listEquals(lightIntensities, oldDelegate.lightIntensities);
  }
}

class _ColorPreset {
  final String label;
  final Color displayColor;
  final double r, g, b;
  const _ColorPreset(this.label, this.displayColor, this.r, this.g, this.b);
}

/// Draws an ornate picture frame around the painting area
/// with light-responsive shading (bevel effect)
class _FramePainter extends CustomPainter {
  final Rect paintingBounds;
  final Offset lightPos;
  final Size screenSize;

  _FramePainter({
    required this.paintingBounds,
    required this.lightPos,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (paintingBounds.isEmpty) return;

    final fw = 14.0; // frame width
    final innerGap = 3.0; // gap between frame inner edge and painting

    // Outer and inner rectangles of the frame
    final outer = paintingBounds.inflate(fw + innerGap);
    final inner = paintingBounds.inflate(-innerGap);

    // Light direction (normalized -1 to 1 from painting center)
    final cx = paintingBounds.center.dx;
    final cy = paintingBounds.center.dy;
    final normLx = ((lightPos.dx * screenSize.width - cx) / (paintingBounds.width / 2)).clamp(-1.0, 1.0);
    final normLy = ((lightPos.dy * screenSize.height - cy) / (paintingBounds.height / 2)).clamp(-1.0, 1.0);

    const darkWood = Color(0xFF1A0E04);
    const midWood = Color(0xFF3D2B1A);
    const lightWood = Color(0xFF6B5240);
    const gold = Color(0xFFB8960C);

    // Helper: interpolate brightness for each frame side
    Color sideColor(double lightFactor) {
      final t = (lightFactor * 0.5 + 0.5).clamp(0.0, 1.0);
      return Color.lerp(darkWood, lightWood, t)!;
    }

    // Top side: brighter when light is above (normLy < 0)
    final topPath = Path()
      ..moveTo(outer.left, outer.top)
      ..lineTo(outer.right, outer.top)
      ..lineTo(inner.right, inner.top)
      ..lineTo(inner.left, inner.top)
      ..close();
    canvas.drawPath(topPath, Paint()..color = sideColor(-normLy));

    // Bottom side: brighter when light is below
    final bottomPath = Path()
      ..moveTo(outer.left, outer.bottom)
      ..lineTo(outer.right, outer.bottom)
      ..lineTo(inner.right, inner.bottom)
      ..lineTo(inner.left, inner.bottom)
      ..close();
    canvas.drawPath(bottomPath, Paint()..color = sideColor(normLy));

    // Left side: brighter when light is to the left
    final leftPath = Path()
      ..moveTo(outer.left, outer.top)
      ..lineTo(inner.left, inner.top)
      ..lineTo(inner.left, inner.bottom)
      ..lineTo(outer.left, outer.bottom)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = sideColor(-normLx));

    // Right side: brighter when light is to the right
    final rightPath = Path()
      ..moveTo(outer.right, outer.top)
      ..lineTo(inner.right, inner.top)
      ..lineTo(inner.right, inner.bottom)
      ..lineTo(outer.right, outer.bottom)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = sideColor(normLx));

    // Gold inner edge (accent line at painting border)
    canvas.drawRect(
      paintingBounds.inflate(0.5),
      Paint()
        ..color = gold.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Gold outer edge
    canvas.drawRect(
      outer.deflate(0.5),
      Paint()
        ..color = gold.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Subtle mid-line groove on frame surface
    final midRect = Rect.lerp(outer, inner, 0.5)!;
    canvas.drawRect(
      midRect,
      Paint()
        ..color = midWood.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Specular highlight on light-facing outer edge
    final highlightAlpha = 0.3;
    if (normLy < -0.1) {
      // Light from above: highlight on top outer edge
      canvas.drawLine(
        Offset(outer.left + fw, outer.top),
        Offset(outer.right - fw, outer.top),
        Paint()
          ..color = gold.withValues(alpha: highlightAlpha * (-normLy))
          ..strokeWidth = 1.5,
      );
    }
    if (normLy > 0.1) {
      canvas.drawLine(
        Offset(outer.left + fw, outer.bottom),
        Offset(outer.right - fw, outer.bottom),
        Paint()
          ..color = gold.withValues(alpha: highlightAlpha * normLy)
          ..strokeWidth = 1.5,
      );
    }
    if (normLx < -0.1) {
      canvas.drawLine(
        Offset(outer.left, outer.top + fw),
        Offset(outer.left, outer.bottom - fw),
        Paint()
          ..color = gold.withValues(alpha: highlightAlpha * (-normLx))
          ..strokeWidth = 1.5,
      );
    }
    if (normLx > 0.1) {
      canvas.drawLine(
        Offset(outer.right, outer.top + fw),
        Offset(outer.right, outer.bottom - fw),
        Paint()
          ..color = gold.withValues(alpha: highlightAlpha * normLx)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) {
    return lightPos != old.lightPos ||
        paintingBounds != old.paintingBounds;
  }
}

/// Detects single taps without interfering with InteractiveViewer's pinch/pan.
/// Only fires if the pointer didn't move more than 10px between down and up.
class _JsonLightTapDetector extends StatefulWidget {
  final void Function(Offset localPosition) onLightTap;
  final Widget child;
  const _JsonLightTapDetector({required this.onLightTap, required this.child});

  @override
  State<_JsonLightTapDetector> createState() => _JsonLightTapDetectorState();
}

class _JsonLightTapDetectorState extends State<_JsonLightTapDetector> {
  Offset? _downPos;
  int _pointerCount = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointerCount++;
        if (_pointerCount == 1) {
          _downPos = event.localPosition;
        } else {
          _downPos = null; // Multi-touch = not a tap
        }
      },
      onPointerUp: (event) {
        _pointerCount = (_pointerCount - 1).clamp(0, 10);
        if (_downPos != null && _pointerCount == 0) {
          final distance = (event.localPosition - _downPos!).distance;
          if (distance < 15) {
            widget.onLightTap(event.localPosition);
          }
        }
        if (_pointerCount == 0) _downPos = null;
      },
      onPointerCancel: (_) {
        _pointerCount = (_pointerCount - 1).clamp(0, 10);
        _downPos = null;
      },
      child: widget.child,
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';
import '../services/translate_service.dart';
import 'detail_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  List<Artwork> _allWorks = [];
  bool _loading = true;
  int _score = 0;
  int _total = 0;
  int _streak = 0;
  Artwork? _currentWork;
  List<String> _choices = [];
  String? _selectedAnswer;
  bool _answered = false;
  bool _wasCorrect = false;
  final _random = Random();

  // Animations
  late AnimationController _resultController;
  late AnimationController _shakeController;
  late AnimationController _confettiController;
  late AnimationController _scoreController;
  late Animation<double> _resultFade;
  late Animation<double> _shakeTween;
  late Animation<double> _scoreBounce;

  // Confetti particles
  List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _resultController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _resultFade = CurvedAnimation(parent: _resultController, curve: Curves.easeOut);

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeTween = Tween<double>(begin: 0, end: 1).animate(_shakeController);

    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _confettiController.addListener(() => setState(() {}));

    _scoreController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scoreBounce = CurvedAnimation(parent: _scoreController, curve: Curves.elasticOut);

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final works = await ArtApi.fetchImpressionistWorks(limit: 100);
      setState(() {
        _allWorks = works.where((w) => w.imageUrl != null).toList();
        _loading = false;
      });
      _nextQuestion();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _nextQuestion() {
    if (_allWorks.length < 4) return;

    _answered = false;
    _wasCorrect = false;
    _selectedAnswer = null;
    _resultController.reset();
    _shakeController.reset();
    _confettiController.reset();
    _particles = [];

    final work = _allWorks[_random.nextInt(_allWorks.length)];
    final correctArtist = work.artist;

    final otherArtists = ArtApi.impressionistArtists
        .where((a) => a != correctArtist)
        .toList()
      ..shuffle(_random);
    final wrongArtists = otherArtists.take(2).toList();

    final choices = [correctArtist, ...wrongArtists]..shuffle(_random);

    setState(() {
      _currentWork = work;
      _choices = choices;
    });
  }

  void _answer(String artist) {
    if (_answered) return;
    final correct = artist == _currentWork!.artist;
    setState(() {
      _answered = true;
      _selectedAnswer = artist;
      _wasCorrect = correct;
      _total++;
      if (correct) {
        _score++;
        _streak++;
      } else {
        _streak = 0;
      }
    });

    _resultController.forward();
    _scoreController.forward(from: 0);

    if (correct) {
      // Confetti!
      _generateConfetti();
      _confettiController.forward();
    } else {
      // Shake!
      _shakeController.forward();
    }
  }

  void _generateConfetti() {
    final size = MediaQuery.of(context).size;
    _particles = List.generate(40, (_) {
      return _ConfettiParticle(
        x: size.width * _random.nextDouble(),
        y: -20.0 - _random.nextDouble() * 100,
        vx: (_random.nextDouble() - 0.5) * 200,
        vy: 200 + _random.nextDouble() * 400,
        size: 4 + _random.nextDouble() * 8,
        color: [
          Colors.amber, Colors.green[400]!, Colors.blue[300]!,
          Colors.pink[300]!, Colors.purple[300]!, Colors.orange[300]!,
        ][_random.nextInt(6)],
        rotation: _random.nextDouble() * 6.28,
      );
    });
  }

  @override
  void dispose() {
    _resultController.dispose();
    _shakeController.dispose();
    _confettiController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allWorks.length < 4) {
      return const Center(child: Text('作品データが不足しています', style: TextStyle(color: Colors.white)));
    }

    final work = _currentWork;
    if (work == null) return const SizedBox();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('名画クイズ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // Score badge with bounce
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.3).animate(_scoreBounce),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$_score / $_total',
                      style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content (with shake animation for wrong answers)
          AnimatedBuilder(
            animation: _shakeTween,
            builder: (context, child) {
              final shake = sin(_shakeController.value * pi * 6) * 12 * (1 - _shakeController.value);
              return Transform.translate(
                offset: Offset(shake, 0),
                child: child,
              );
            },
            child: SafeArea(
              child: Column(
                children: [
                  // Streak indicator
                  if (_streak > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '$_streak連続正解!',
                        style: TextStyle(color: Colors.amber.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('この作品の画家は？', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
                  ),
                  const SizedBox(height: 8),

                  // Artwork image
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: MouseRegion(
                        cursor: _answered ? SystemMouseCursors.click : SystemMouseCursors.basic,
                        child: GestureDetector(
                        onTap: _answered ? () {
                          Navigator.push(context, MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => DetailScreen(artwork: work),
                          ));
                        } : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: 'artwork_${work.id}',
                                child: CachedNetworkImage(
                                  imageUrl: work.imageUrl!,
                                  fit: BoxFit.contain,
                                  httpHeaders: ArtApi.imageHeaders,
                                  placeholder: (_, __) => Container(color: Colors.grey[900]),
                                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 48)),
                                ),
                              ),
                              if (_answered)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: FadeTransition(
                                    opacity: _resultFade,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(work.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                          Text('${work.date}  •  タップで詳細', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Choices
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          ..._choices.map((artist) => _buildChoice(artist, work, isMobile)),
                          if (_answered) ...[
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: FadeTransition(
                                opacity: _resultFade,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                  onTap: _nextQuestion,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                    ),
                                    child: const Text('次の問題 →', style: TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.w600)),
                                  ),
                                )),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Result overlay (正解! / 残念...)
          if (_answered)
            Positioned.fill(
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: _resultFade,
                  child: Center(
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.3, end: 1.0).animate(
                        CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                        decoration: BoxDecoration(
                          color: (_wasCorrect ? Colors.green : Colors.red).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (_wasCorrect ? Colors.green : Colors.red).withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Text(
                          _wasCorrect ? '正解!' : '残念...',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Confetti
          if (_confettiController.isAnimating)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiController.value,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChoice(String artist, Artwork work, bool isMobile) {
    final isCorrect = artist == work.artist;
    final isSelected = artist == _selectedAnswer;
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (!_answered) {
      bgColor = Colors.white.withValues(alpha: 0.05);
      borderColor = Colors.white.withValues(alpha: 0.1);
      textColor = Colors.white;
    } else if (isCorrect) {
      bgColor = Colors.green.withValues(alpha: 0.15);
      borderColor = Colors.green.withValues(alpha: 0.5);
      textColor = Colors.green[300]!;
    } else if (isSelected) {
      bgColor = Colors.red.withValues(alpha: 0.15);
      borderColor = Colors.red.withValues(alpha: 0.5);
      textColor = Colors.red[300]!;
    } else {
      bgColor = Colors.white.withValues(alpha: 0.02);
      borderColor = Colors.white.withValues(alpha: 0.05);
      textColor = Colors.white38;
    }

    final jaArtist = TranslateService.translateArtist(artist);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(
        cursor: _answered ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
        onTap: () => _answer(artist),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: isMobile ? 14 : 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: _answered && isCorrect ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  jaArtist,
                  style: TextStyle(color: textColor, fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.w500),
                ),
              ),
              if (_answered && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
              if (_answered && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red, size: 24),
            ],
          ),
        ),
      )),
    );
  }
}

// Confetti particle data
class _ConfettiParticle {
  double x, y, vx, vy, size, rotation;
  Color color;
  _ConfettiParticle({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.size, required this.color, required this.rotation,
  });
}

// Confetti painter
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    for (final p in particles) {
      final x = p.x + p.vx * t;
      final y = p.y + p.vy * t + 200 * t * t; // gravity
      final rotation = p.rotation + t * 10;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.8);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

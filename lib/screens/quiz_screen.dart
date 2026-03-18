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

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  List<Artwork> _allWorks = [];
  bool _loading = true;
  int _score = 0;
  int _total = 0;
  Artwork? _currentWork;
  List<String> _choices = [];
  String? _selectedAnswer;
  bool _answered = false;
  late AnimationController _resultAnimController;
  late Animation<double> _resultAnim;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _resultAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _resultAnim = CurvedAnimation(parent: _resultAnimController, curve: Curves.easeOut);
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
    _selectedAnswer = null;
    _resultAnimController.reset();

    // Pick a random work
    final work = _allWorks[_random.nextInt(_allWorks.length)];
    final correctArtist = work.artist;

    // Get 2 wrong artists (different from correct)
    final otherArtists = ArtApi.impressionistArtists
        .where((a) => a != correctArtist)
        .toList()
      ..shuffle(_random);
    final wrongArtists = otherArtists.take(2).toList();

    // Build choices and shuffle
    final choices = [
      correctArtist,
      ...wrongArtists,
    ]..shuffle(_random);

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
      _total++;
      if (correct) _score++;
    });
    _resultAnimController.forward();
  }

  @override
  void dispose() {
    _resultAnimController.dispose();
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

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                const Text('名画クイズ', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$_score / $_total',
                    style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('この作品の画家は？', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
          const SizedBox(height: 12),

          // Artwork image
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      // Show title after answering
                      if (_answered)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: FadeTransition(
                            opacity: _resultAnim,
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
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Choices
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  ..._choices.map((artist) {
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
                      child: GestureDetector(
                        onTap: () => _answer(artist),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: isMobile ? 14 : 16),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
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
                                const Icon(Icons.check_circle, color: Colors.green, size: 22),
                              if (_answered && isSelected && !isCorrect)
                                const Icon(Icons.cancel, color: Colors.red, size: 22),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_answered) ...[
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FadeTransition(
                        opacity: _resultAnim,
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
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

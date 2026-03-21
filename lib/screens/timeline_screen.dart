import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../widgets/art_image.dart';
import '../models/timeline_event.dart';
import '../models/artist.dart';
import '../models/artwork.dart';
import '../services/art_api.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  Map<String, Artwork> _artistWorks = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorks();
  }

  Future<void> _loadWorks() async {
    try {
      final works = await artApi.fetchHighlights(limit: 20);
      final map = <String, Artwork>{};
      for (final w in works) {
        if (w.imageUrl != null && !map.containsKey(w.artist)) {
          map[w.artist] = w;
        }
      }
      if (mounted) setState(() { _artistWorks = map; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _imageUrlForEvent(TimelineEvent event) {
    if (event.artist == null) return null;
    // Match Japanese artist name to English name
    for (final entry in _artistWorks.entries) {
      final jaName = ArtistProfile.all.where((a) => a.name == entry.key).firstOrNull?.nameJa ?? '';
      if (jaName.contains(event.artist!) || event.artist!.contains(jaName.split('・').last)) {
        return entry.value.imageUrl;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final events = TimelineEvent.all;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                const Text('印象派の歴史', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('1863–1906', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: isMobile ? _buildVertical(events) : _buildHorizontal(events),
          ),
        ],
      ),
    );
  }

  // --- Mobile: vertical with artist bars on left ---
  Widget _buildVertical(List<TimelineEvent> events) {
    const startYear = 1830;
    const endYear = 1910;
    const range = endYear - startYear;

    final artists = ArtistProfile.all.where((a) {
      final born = int.tryParse(a.born) ?? 0;
      return born >= 1830 && born <= 1870;
    }).toList()
      ..sort((a, b) => (int.tryParse(a.born) ?? 0).compareTo(int.tryParse(b.born) ?? 0));

    final barColors = [
      Colors.blue[300]!, Colors.orange[300]!, Colors.purple[300]!,
      Colors.green[300]!, Colors.red[300]!, Colors.teal[300]!,
      Colors.amber[300]!, Colors.pink[300]!, Colors.cyan[300]!,
      Colors.lime[300]!,
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;
        final yearFraction = (event.year - startYear) / range;
        final imageUrl = _imageUrlForEvent(event);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot
              Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: event.type.color.withValues(alpha: 0.15),
                      border: Border.all(color: event.type.color.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Icon(event.type.icon, color: event.type.color, size: 10),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 1, color: Colors.white.withValues(alpha: 0.06))),
                ],
              ),
              const SizedBox(width: 8),
              // Content card
              Expanded(child: _buildCard(event, compact: true, imageUrl: imageUrl)),
            ],
          ),
        );
      },
    );
  }

  // --- PC: horizontal with grab cursor ---
  Widget _buildHorizontal(List<TimelineEvent> events) {
    final screenHeight = MediaQuery.of(context).size.height;
    final showBars = screenHeight > 500; // Hide bars on very short screens
    return Column(
      children: [
        if (showBars) _buildArtistBarsPC(screenHeight),
        const SizedBox(height: 4),
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  _scrollController.jumpTo(
                    (_scrollController.offset + event.scrollDelta.dy).clamp(
                      0.0, _scrollController.position.maxScrollExtent,
                    ),
                  );
                }
              },
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                  PointerDeviceKind.touch, PointerDeviceKind.mouse,
                }),
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final imageUrl = _imageUrlForEvent(event);
                    return SizedBox(
                      width: 300,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: event.type.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${event.year}', style: TextStyle(color: event.type.color, fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                Icon(event.type.icon, color: event.type.color, size: 16),
                                const SizedBox(width: 4),
                                Text(event.type.label, style: TextStyle(color: event.type.color.withValues(alpha: 0.7), fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: event.type.color)),
                                Expanded(child: Container(height: 2, color: Colors.white.withValues(alpha: 0.06))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(child: _buildCard(event, compact: false, imageUrl: imageUrl)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(TimelineEvent event, {required bool compact, String? imageUrl}) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 16 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [event.type.color.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.02)],
        ),
        border: Border.all(color: event.type.color.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          // Image
          if (imageUrl != null)
            ArtImage(
              imageUrl: imageUrl,
              height: compact ? 100 : 140,
              width: double.infinity,
              fit: BoxFit.cover,

              placeholder: (_, __) => Container(height: compact ? 100 : 140, color: Colors.grey[900]),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: event.type.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${event.year}年  ${event.type.label}',
                        style: TextStyle(color: event.type.color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: event.type.color.withValues(alpha: 0.5), width: 3)),
                  ),
                  child: Text(event.title, style: TextStyle(color: Colors.white, fontSize: compact ? 15 : 18, fontWeight: FontWeight.w600)),
                ),
                if (event.artist != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 13),
                    child: Text(event.artist!, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: compact ? 10 : 12)),
                  ),
                ],
                const SizedBox(height: 8),
                Text(event.description,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: compact ? 12 : 14, height: 1.6)),
                if (event.worldContext != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.public, color: Colors.white.withValues(alpha: 0.3), size: compact ? 12 : 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            event.worldContext!,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: compact ? 11 : 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistBarsPC(double screenHeight) {
    final artists = ArtistProfile.all.where((a) {
      final born = int.tryParse(a.born) ?? 0;
      return born >= 1830 && born <= 1870;
    }).toList()
      ..sort((a, b) => (int.tryParse(a.born) ?? 0).compareTo(int.tryParse(b.born) ?? 0));

    const startYear = 1830;
    const endYear = 1910;
    const range = endYear - startYear;

    final colors = [
      Colors.blue[300]!, Colors.orange[300]!, Colors.purple[300]!,
      Colors.green[300]!, Colors.red[300]!, Colors.teal[300]!,
      Colors.amber[300]!, Colors.pink[300]!, Colors.cyan[300]!, Colors.lime[300]!,
    ];

    final compact = screenHeight < 700;
    final barHeight = compact ? 120.0 : 220.0;
    final barThickness = compact ? 12.0 : 16.0;
    final barSpacing = compact ? 12.0 : 18.0;
    final fontSize = compact ? 8.0 : 10.0;

    return Container(
      height: barHeight,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('画家の生涯', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
          const SizedBox(height: 4),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    // Year markers
                    for (final y in [1840, 1860, 1880, 1900])
                      Positioned(
                        left: (y - startYear) / range * width,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.05),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Text('$y', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9)),
                            ),
                          ),
                        ),
                      ),
                    // Artist bars with names inside
                    ...artists.take(10).toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final a = entry.value;
                      final born = int.tryParse(a.born) ?? startYear;
                      final died = int.tryParse(a.died) ?? endYear;
                      final left = (born - startYear) / range * width;
                      final barWidth = (died - born) / range * width;
                      final top = i * barSpacing;
                      final shortName = a.nameJa.split('・').last.replaceAll('＝', '');
                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: barWidth,
                          height: barThickness,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length].withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '$shortName (${a.born}–${a.died})',
                            style: TextStyle(color: colors[i % colors.length], fontSize: fontSize, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

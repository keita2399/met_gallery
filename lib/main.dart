import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'services/art_api.dart';
import 'screens/home_screen.dart';
import 'screens/detail_screen.dart';
import 'widgets/install_prompt_stub.dart' if (dart.library.js_interop) 'widgets/install_prompt_web.dart';

int? _getArtworkIdFromUrl() {
  if (!kIsWeb) return null;
  final idParam = Uri.base.queryParameters['id'];
  if (idParam != null) {
    return int.tryParse(idParam);
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initInstallPrompt();

  final artworkId = _getArtworkIdFromUrl();

  runApp(MetGalleryApp(artworkId: artworkId));
}

class MetGalleryApp extends StatelessWidget {
  final int? artworkId;
  const MetGalleryApp({super.key, this.artworkId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'メトロポリタンさんぽ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B0000), // Met Museumの赤
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: artworkId != null
          ? DeepLinkScreen(artworkId: artworkId!)
          : const HomeScreen(),
    );
  }
}

class DeepLinkScreen extends StatefulWidget {
  final int artworkId;
  const DeepLinkScreen({super.key, required this.artworkId});

  @override
  State<DeepLinkScreen> createState() => _DeepLinkScreenState();
}

class _DeepLinkScreenState extends State<DeepLinkScreen> {
  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  Future<void> _loadArtwork() async {
    try {
      final artwork = await ArtApi.fetchArtworkDetail(widget.artworkId);
      if (artwork != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(artwork: artwork),
          ),
        );
      } else if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

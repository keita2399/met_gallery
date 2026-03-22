import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'config/app_config.dart';
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

/// 共通エントリポイント（main_met.dart / main_aic.dart から呼ばれる）
void startApp() {
  WidgetsFlutterBinding.ensureInitialized();
  initInstallPrompt();

  final artworkId = _getArtworkIdFromUrl();

  // スプラッシュを即座に削除（Flutterが描画を開始した時点で不要）
  WidgetsBinding.instance.addPostFrameCallback((_) {
    removeSplash();
  });

  runApp(GalleryApp(artworkId: artworkId));
}

class GalleryApp extends StatelessWidget {
  final int? artworkId;
  const GalleryApp({super.key, this.artworkId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appConfig.themeColor,
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
      final artwork = await artApi.fetchArtworkDetail(widget.artworkId);
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

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'install_prompt_stub.dart' if (dart.library.js_interop) 'install_prompt_web.dart';

class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _show = false;
  bool _isIos = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _checkShouldShow();
  }

  Future<void> _checkShouldShow() async {
    // Don't show if already installed as PWA
    if (isRunningAsPwa()) return;

    // Don't show if user dismissed before
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('install_banner_dismissed') == true) return;

    if (!mounted) return;
    setState(() {
      _show = true;
      _isIos = isIosSafari();
    });
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('install_banner_dismissed', true);
  }

  void _install() {
    if (_isIos) {
      // iOS: show instruction dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a1a),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('ホーム画面に追加', style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.ios_share, color: Colors.blue[300], size: 40),
              const SizedBox(height: 12),
              Text(
                '① 下のバーの共有ボタン（□↑）をタップ\n② 「ホーム画面に追加」を選択',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.6),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); _dismiss(); },
              child: const Text('OK', style: TextStyle(color: Colors.amber)),
            ),
          ],
        ),
      );
    } else {
      // Chrome/Edge: trigger install prompt
      triggerInstallPrompt();
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.install_mobile, color: Colors.amber.withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ホーム画面に追加できます',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
            onTap: _install,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('追加', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          )),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
            onTap: _dismiss,
            child: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.3), size: 18),
          )),
        ],
      ),
    );
  }
}

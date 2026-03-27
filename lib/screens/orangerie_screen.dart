import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class OrangerieScreen extends StatefulWidget {
  const OrangerieScreen({super.key});

  @override
  State<OrangerieScreen> createState() => _OrangerieScreenState();
}

class _OrangerieScreenState extends State<OrangerieScreen> {
  static bool _registered = false;

  @override
  void initState() {
    super.initState();
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(
        'orangerie-iframe',
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = 'orangerie.html'
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..allowFullscreen = true
            ..setAttribute('allow', 'accelerometer; gyroscope');
          return iframe;
        },
      );
      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: 'orangerie-iframe');
  }
}

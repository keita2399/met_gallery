import 'package:flutter/material.dart';
import '../models/artwork.dart';
import '../screens/detail_screen.dart';
import 'art_image.dart';

/// 作品グリッドカード（favorites, artist, gacha履歴等で共通利用）
///
/// 画像全面 + 下部グラデーション + テキストオーバーレイのカードUI
class ArtworkCard extends StatelessWidget {
  final Artwork artwork;

  /// タイトル表示文字列。省略時は artwork.title を使用
  final String? title;

  /// サブタイトル（画家名等）。省略時は非表示
  final String? subtitle;

  /// Hero アニメーション用タグ。省略時は Hero なし
  final String? heroTag;

  /// タップ時コールバック。省略時は DetailScreen へ遷移
  final VoidCallback? onTap;

  /// カードの角丸半径（デフォルト 12）
  final double borderRadius;

  const ArtworkCard({
    super.key,
    required this.artwork,
    this.title,
    this.subtitle,
    this.heroTag,
    this.onTap,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? artwork.title;

    Widget imageWidget = ArtImage(
      imageUrl: artwork.imageUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: Colors.grey[900]),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
        child: const Icon(Icons.broken_image, color: Colors.white24),
      ),
    );

    if (heroTag != null) {
      imageWidget = Hero(tag: heroTag!, child: imageWidget);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ??
            () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => DetailScreen(artwork: artwork),
                  ),
                ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (artwork.imageUrl != null) imageWidget,
              // 下部グラデーションオーバーレイ
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              // テキスト（下部）
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

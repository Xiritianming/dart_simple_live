import 'package:flutter/material.dart';

import 'danmaku_image_cache.dart';
import 'models/danmaku_item.dart';

class ScrollDanmakuPainter extends CustomPainter {
  final List<DanmakuItem> items;
  final double fontSize;
  final int fontWeight;
  final bool showStroke;
  final int duration;
  final int tick;
  final double devicePixelRatio;
  final double opacity;
  final DanmakuImageCache imageCache;

  ScrollDanmakuPainter({
    required this.items,
    required this.fontSize,
    required this.fontWeight,
    required this.showStroke,
    required this.duration,
    required this.tick,
    required this.devicePixelRatio,
    required this.opacity,
    required this.imageCache,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      item.lastDrawTick ??= item.creationTime;
      item.xPosition += (item.lastDrawTick! - tick) /
          (duration * 1000) *
          (size.width + item.width);
      item.lastDrawTick = tick;
      if (item.xPosition < -item.width || item.xPosition > size.width) continue;
      imageCache.paintComment(
          canvas,
          item,
          Offset(item.xPosition, item.yPosition),
          fontSize,
          fontWeight,
          showStroke,
          devicePixelRatio,
          opacity);
    }
  }

  @override
  bool shouldRepaint(covariant ScrollDanmakuPainter oldDelegate) => true;
}

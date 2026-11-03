import 'package:flutter/material.dart';

import 'danmaku_image_cache.dart';
import 'models/danmaku_item.dart';

class StaticDanmakuPainter extends CustomPainter {
  final List<DanmakuItem> topItems;
  final List<DanmakuItem> bottomItems;
  final double fontSize;
  final int fontWeight;
  final bool showStroke;
  final double danmakuHeight;
  final double devicePixelRatio;
  final double opacity;
  final DanmakuImageCache imageCache;

  StaticDanmakuPainter({
    required this.topItems,
    required this.bottomItems,
    required this.fontSize,
    required this.fontWeight,
    required this.showStroke,
    required this.danmakuHeight,
    required this.devicePixelRatio,
    required this.opacity,
    required this.imageCache,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in topItems) {
      _paintItem(canvas, item, size, item.yPosition);
    }
    for (final item in bottomItems) {
      _paintItem(
          canvas, item, size, size.height - item.yPosition - danmakuHeight);
    }
  }

  void _paintItem(Canvas canvas, DanmakuItem item, Size size, double dy) {
    item.xPosition = (size.width - item.width) / 2;
    imageCache.paintComment(canvas, item, Offset(item.xPosition, dy), fontSize,
        fontWeight, showStroke, devicePixelRatio, opacity);
  }

  @override
  bool shouldRepaint(covariant StaticDanmakuPainter oldDelegate) => true;
}

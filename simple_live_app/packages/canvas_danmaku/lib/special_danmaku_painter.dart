import 'dart:math';
import 'dart:ui' as ui;

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:canvas_danmaku/models/danmaku_item.dart';
import 'package:flutter/material.dart';
import 'danmaku_image_cache.dart';

class SpecialDanmakuPainter extends CustomPainter {
  final double progress;
  final List<DanmakuItem> specialDanmakuItems;
  final double fontSize;
  final int fontWeight;
  final bool running;
  final int tick;
  final int batchThreshold;
  final DanmakuImageCache imageCache;
  final double devicePixelRatio;
  final double opacity;

  SpecialDanmakuPainter(
    this.progress,
    this.specialDanmakuItems,
    this.fontSize,
    this.fontWeight,
    this.running,
    this.tick, {
    required this.imageCache,
    required this.devicePixelRatio,
    required this.opacity,
    this.batchThreshold = 10, // 默认值为10，可以自行调整
  });

  @override
  void paint(Canvas canvas, Size size) {
    var pictureCanvas = canvas;
    var batch = specialDanmakuItems.length > batchThreshold;
    late ui.PictureRecorder pictureRecorder;
    if (batch) {
      pictureRecorder = ui.PictureRecorder();
      pictureCanvas = Canvas(pictureRecorder);
    }
    for (final item in specialDanmakuItems) {
      final elapsed = tick - item.creationTime;
      final content = item.content as SpecialDanmakuContentItem;
      if (elapsed >= 0 && elapsed < content.duration) {
        _paintSpecialDanmaku(pictureCanvas, item, content, size, elapsed);
      }
    }
    if (batch) {
      final picture = pictureRecorder.endRecording();
      canvas.drawPicture(picture);
      picture.dispose();
    }
  }

  void _paintSpecialDanmaku(Canvas canvas, DanmakuItem cachedItem,
      SpecialDanmakuContentItem item, Size size, int elapsed) {
    // 透明度动画
    late final alpha =
        item.alphaTween?.transform(elapsed / item.duration) ?? item.color.a;
    item.painterCache ??= TextPainter(
      text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: item.alphaTween == null
                ? item.color
                : item.color.withAlpha(255),
            fontSize: item.fontSize,
            fontWeight: FontWeight.values[fontWeight],
            shadows: item.hasStroke
                ? [
                    Shadow(
                      color: Colors.black.withValues(
                          alpha: item.alphaTween == null ? item.color.a : 1),
                      blurRadius: 2,
                    )
                  ]
                : null,
          )),
      textDirection: TextDirection.ltr,
    )..layout();

    // 路径动画 TODO

    // else 位移动画
    late double dx, dy;
    if (elapsed > item.translationStartDelay) {
      late double translateProgress = item.easingType.transform(min(
          1.0,
          (elapsed - item.translationStartDelay) /
              max(1, item.translationDuration)));

      double getOffset(Tween<double> tween) => tween is ConstantTween
          ? tween.begin!
          : tween.transform(translateProgress);

      dx = getOffset(item.translateXTween) * size.width;
      dy = getOffset(item.translateYTween) * size.height;
    } else {
      dx = item.translateXTween.begin! * size.width;
      dy = item.translateYTween.begin! * size.height;
    }

    void paintAt(Offset offset) => imageCache.paint(
          canvas: canvas,
          item: cachedItem,
          position: offset,
          size: item.painterCache!.size,
          devicePixelRatio: devicePixelRatio,
          opacity: opacity * (item.alphaTween == null ? 1 : alpha),
          draw: (target, position) =>
              item.painterCache!.paint(target, position),
        );
    if (item.matrix != null) {
      canvas.save();
      canvas.translate(dx, dy);
      canvas.transform(item.matrix!.storage);
      paintAt(Offset.zero);
      canvas.restore();
    } else {
      paintAt(Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant SpecialDanmakuPainter oldDelegate) {
    return true;
  }
}

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'models/danmaku_item.dart';
import 'utils/utils.dart';

/// Stores only active comments. At capacity, drawing falls back to paragraphs.
class DanmakuImageCache {
  final int maxBytes;
  final _images = <DanmakuItem, ui.Image>{};
  int _bytes = 0;
  static const padding = 4.0;

  DanmakuImageCache({this.maxBytes = 32 * 1024 * 1024});

  int get bytes => _bytes;
  int get length => _images.length;

  void paintComment(
      Canvas canvas,
      DanmakuItem item,
      Offset position,
      double fontSize,
      int fontWeight,
      bool showStroke,
      double devicePixelRatio,
      double opacity) {
    paint(
      canvas: canvas,
      item: item,
      position: position,
      size: Size(item.width, item.height),
      devicePixelRatio: devicePixelRatio,
      opacity: opacity,
      draw: (target, offset) {
        item.paragraph ??= Utils.generateParagraph(
            item.content, item.width, fontSize, fontWeight);
        if (showStroke) {
          item.strokeParagraph ??= Utils.generateStrokeParagraph(
              item.content, item.width, fontSize, fontWeight);
          target.drawParagraph(item.strokeParagraph!, offset);
        }
        if (item.content.selfSend) {
          target.drawRect(
            offset.translate(-2, 2) &
                (Size(item.width, item.height) + const Offset(4, 0)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = const Color(0xFF4CAF50),
          );
        }
        target.drawParagraph(item.paragraph!, offset);
      },
    );
  }

  void paint({
    required Canvas canvas,
    required DanmakuItem item,
    required Offset position,
    required Size size,
    required double devicePixelRatio,
    required double opacity,
    required void Function(Canvas, Offset) draw,
  }) {
    if (opacity <= 0 || size.isEmpty) return;
    final bounds = Rect.fromLTWH(-padding, -padding, size.width + padding * 2,
        size.height + padding * 2);
    var image = _images[item];
    if (image == null) {
      final width = (bounds.width * devicePixelRatio).ceil();
      final height = (bounds.height * devicePixelRatio).ceil();
      final imageBytes = width * height * 4;
      if (width <= 8192 && height <= 8192 && _bytes + imageBytes <= maxBytes) {
        final recorder = ui.PictureRecorder();
        final recordingCanvas = Canvas(recorder)
          ..scale(devicePixelRatio)
          ..translate(padding, padding);
        draw(recordingCanvas, Offset.zero);
        final picture = recorder.endRecording();
        try {
          image = picture.toImageSync(width, height);
        } finally {
          picture.dispose();
        }
        _images[item] = image;
        _bytes += imageBytes;
      }
    }
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1));
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        bounds.shift(position),
        paint,
      );
    } else {
      // Preserve stroke/fill opacity together using only this comment's bounds.
      canvas.save();
      if (opacity < 1) canvas.saveLayer(bounds.shift(position), paint);
      draw(canvas, position);
      if (opacity < 1) canvas.restore();
      canvas.restore();
    }
  }

  void remove(DanmakuItem item) {
    final image = _images.remove(item);
    if (image == null) return;
    _bytes -= image.width * image.height * 4;
    image.dispose();
  }

  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _bytes = 0;
  }
}

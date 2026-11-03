import 'dart:ui' as ui;

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:canvas_danmaku/danmaku_image_cache.dart';
import 'package:canvas_danmaku/danmaku_ticker.dart';
import 'package:canvas_danmaku/scroll_danmaku_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bitmap is reused across positions and opacity, then released', () {
    final cache = DanmakuImageCache(maxBytes: 4096);
    final item = DanmakuItem(
        content: DanmakuContentItem('text'),
        creationTime: 0,
        width: 10,
        height: 10);
    var draws = 0;
    void paint(double opacity) {
      final recorder = ui.PictureRecorder();
      cache.paint(
          canvas: Canvas(recorder),
          item: item,
          position: Offset(draws.toDouble(), 0),
          size: const Size(10, 10),
          devicePixelRatio: 1,
          opacity: opacity,
          draw: (canvas, offset) {
            draws++;
            canvas.drawRect(
                offset & const Size(10, 10), Paint()..color = Colors.red);
          });
      recorder.endRecording().dispose();
    }

    paint(1);
    paint(0.5);
    expect(draws, 1);
    expect(cache.bytes, 18 * 18 * 4);
    cache.remove(item);
    expect(cache.bytes, 0);
    expect(cache.length, 0);
  });

  test('raster cache respects budget and falls back without losing content',
      () {
    final cache = DanmakuImageCache(maxBytes: 1);
    var draws = 0;
    final recorder = ui.PictureRecorder();
    cache.paint(
        canvas: Canvas(recorder),
        item: DanmakuItem(
            content: DanmakuContentItem('text'),
            creationTime: 0,
            width: 10,
            height: 10),
        position: Offset.zero,
        size: const Size(10, 10),
        devicePixelRatio: 2,
        opacity: 0.5,
        draw: (canvas, offset) {
          draws++;
          canvas.drawRect(
              offset & const Size(10, 10), Paint()..color = Colors.red);
        });
    recorder.endRecording().dispose();
    expect(draws, 1);
    expect(cache.bytes, 0);
    expect(cache.length, 0);
  });

  testWidgets('60fps cap keeps elapsed time at 160Hz and 60Hz', (tester) async {
    final ticker = DanmakuTicker(vsync: tester);
    var frames = 0;
    ticker.addListener(() => frames++);
    ticker.repeat();
    await tester.pump();
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(microseconds: 6250));
    }
    expect(frames, inInclusiveRange(60, 62));
    expect(ticker.elapsedMilliseconds, 1000);
    ticker.stop();
    final before = frames;
    await tester.pump(const Duration(seconds: 1));
    expect(frames, before);
    ticker.repeat();
    await tester.pump();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(frames - before, inInclusiveRange(60, 62));
    expect(ticker.elapsedMilliseconds, inInclusiveRange(2000, 2001));
    ticker.maxFps = 0;
    final uncapped = frames;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(microseconds: 6250));
    }
    expect(frames - uncapped, 20);
    ticker.dispose();
  });

  testWidgets('empty, cleared and hidden overlays stop producing frames',
      (tester) async {
    late DanmakuController controller;
    final key = GlobalKey();
    Widget view({bool enabled = true, double ratio = 1}) => Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(devicePixelRatio: ratio),
            child: TickerMode(
                enabled: enabled,
                child: SizedBox(
                  width: 400,
                  height: 200,
                  child: DanmakuScreen(
                    key: key,
                    option: DanmakuOption(duration: 1, opacity: 0.5),
                    createdController: (value) => controller = value,
                  ),
                )),
          ),
        );
    await tester.pumpWidget(view());
    expect(tester.binding.hasScheduledFrame, isFalse);
    controller.addDanmaku(DanmakuContentItem('moving text'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final scroll = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<ScrollDanmakuPainter>()
        .single;
    final cache = scroll.imageCache;
    expect(cache.length, 1);
    expect(find.byType(Opacity), findsNothing);
    final oldBytes = cache.bytes;
    await tester.pumpWidget(view(ratio: 2));
    expect(cache.bytes, greaterThan(oldBytes));
    controller.updateOption(controller.option.copyWith(fontSize: 24));
    await tester.pump();
    expect(tester.takeException(), isNull);
    controller.pause();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(cache.length, 1);
    controller.resume();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(cache.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(cache.length, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(cache.length, 1);
    await tester.pumpWidget(view(enabled: false, ratio: 2));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(view(ratio: 2));
    controller.clear();
    await tester.pump();
    expect(cache.bytes, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    controller.addDanmaku(DanmakuContentItem('expires'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(cache.bytes, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  test('cached bitmap opacity is applied once to the combined content',
      () async {
    final cache = DanmakuImageCache();
    final item = DanmakuItem(
        content: DanmakuContentItem('alpha'),
        creationTime: 0,
        width: 10,
        height: 10);
    var draws = 0;
    Future<int> alpha(double opacity) async {
      final recorder = ui.PictureRecorder();
      cache.paint(
          canvas: Canvas(recorder),
          item: item,
          position: const Offset(5, 5),
          size: const Size(10, 10),
          devicePixelRatio: 1,
          opacity: opacity,
          draw: (canvas, offset) {
            draws++;
            canvas.drawRect(
                offset & const Size(10, 10), Paint()..color = Colors.red);
            canvas.drawRect(
                offset & const Size(10, 10), Paint()..color = Colors.blue);
          });
      final picture = recorder.endRecording();
      final image = await picture.toImage(24, 24);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final value = data!.getUint8((10 * 24 + 10) * 4 + 3);
      image.dispose();
      picture.dispose();
      return value;
    }

    expect(await alpha(1), 255);
    expect(await alpha(0.5), inInclusiveRange(127, 128));
    expect(draws, 1);
    cache.clear();
  });

  testWidgets('static and fading special comments expire and release images',
      (tester) async {
    late DanmakuController controller;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
          data: const MediaQueryData(),
          child: DanmakuScreen(
            option: DanmakuOption(duration: 1),
            createdController: (value) => controller = value,
          )),
    ));
    controller.addDanmaku(DanmakuContentItem('top', type: DanmakuItemType.top));
    controller
        .addDanmaku(DanmakuContentItem('bottom', type: DanmakuItemType.bottom));
    controller.addDanmaku(SpecialDanmakuContentItem(
      'fade',
      color: Colors.white,
      duration: 1000,
      fontSize: 18,
      hasStroke: true,
      translateXTween: Tween(begin: 0.1, end: 0.8),
      translateYTween: ConstantTween(0.5),
      alphaTween: Tween(begin: 1, end: 0),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final cache = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<ScrollDanmakuPainter>()
        .single
        .imageCache;
    expect(cache.length, 3);
    controller.updateOption(controller.option.copyWith(fontWeight: 5));
    await tester.pump();
    expect(cache.length, 3);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(cache.bytes, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

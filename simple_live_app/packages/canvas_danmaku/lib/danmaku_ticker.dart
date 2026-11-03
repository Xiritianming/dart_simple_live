import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Keeps animation time independent of the number of frames painted.
class DanmakuTicker extends ChangeNotifier {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  Duration _base = Duration.zero;
  double _nextFrame = 0;
  int _maxFps;

  DanmakuTicker({required TickerProvider vsync, int maxFps = 60})
      : _maxFps = maxFps {
    _ticker = vsync.createTicker(_onTick);
  }

  int get elapsedMilliseconds => _elapsed.inMilliseconds;
  bool get isAnimating => _ticker.isActive;
  double get value => 0;

  set maxFps(int value) {
    _maxFps = value;
    _nextFrame = 0;
  }

  void repeat() {
    if (_ticker.isActive) return;
    _base = _elapsed;
    _nextFrame = 0;
    _ticker.start();
  }

  void stop() => _ticker.stop();

  void _onTick(Duration elapsed) {
    _elapsed = _base + elapsed;
    final now = elapsed.inMicroseconds.toDouble();
    // Allow timestamp rounding at the display's exact refresh boundary.
    if (_maxFps > 0 && now + 500 < _nextFrame) return;
    if (_maxFps > 0) {
      final interval = 1000000 / _maxFps;
      _nextFrame = (((now + 500) / interval).floor() + 1) * interval;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

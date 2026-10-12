import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// أصوات الشطرنج (WAV).
///
/// تستخدم [AudioPool] المخصصة للمؤثرات القصيرة: تُحمَّل الأصوات مرة
/// واحدة وتُشغَّل فورًا عند كل نقلة بدون stop/seek/resume (التي كانت
/// تتأخر أو تفشل في تشغيل الصوت ثانيةً على بعض الأجهزة) ويمكن تداخل
/// صوتين (نقلة + كش) دون قطع أحدهما الآخر.
class SoundService {
  SoundService() {
    _init();
  }

  static const Map<String, String> _files = {
    'move': 'sounds/move.wav',
    'capture': 'sounds/capture.wav',
    'check': 'sounds/check.wav',
    'checkmate': 'sounds/checkmate.wav',
    'castle': 'sounds/castle.wav',
    'promotion': 'sounds/promote.wav',
    'game_over': 'sounds/game_end.wav',
    'game_start': 'sounds/game_start.wav',
    'draw': 'sounds/draw.wav',
    'illegal': 'sounds/illegal_move.wav',
  };

  final Map<String, AudioPool> _pools = <String, AudioPool>{};

  bool enabled = true;
  bool _disposed = false;
  Future<void>? _ready;

  Future<void> _init() {
    _ready ??= _preparePools();
    return _ready!;
  }

  Future<void> _preparePools() async {
    // أي ملفات متكررة تشارك Pool واحدة.
    final byPath = <String, AudioPool>{};

    for (final entry in _files.entries) {
      if (_disposed) return;

      try {
        var pool = byPath[entry.value];

        pool ??= await AudioPool.createFromAsset(
          path: entry.value,
          maxPlayers: 3,
        );

        byPath[entry.value] = pool;
        _pools[entry.key] = pool;
      } catch (_) {
        // يبقى التطبيق يعمل حتى إذا تعذر تحميل مؤثر صوتي.
      }
    }
  }

  /// لا نستخدم await في مسار النقلة حتى لا يتأخر تحديث الرقعة.
  void _playNow(String kind) {
    if (!enabled || _disposed) return;

    () async {
      try {
        await _init();

        final pool = _pools[kind] ?? _pools['move'];

        if (pool == null || _disposed) return;

        unawaited(pool.start());
      } catch (_) {}
    }();
  }

  void playMove() => _playNow('move');
  void playCapture() => _playNow('capture');
  void playCheck() => _playNow('check');
  void playCheckmate() => _playNow('checkmate');
  void playCastle() => _playNow('castle');
  void playPromotion() => _playNow('promotion');
  void playGameOver() => _playNow('game_over');
  void playGameStart() => _playNow('game_start');
  void playDraw() => _playNow('draw');
  void playIllegal() => _playNow('illegal');

  void playKind(String kind) {
    if (_files.containsKey(kind)) {
      _playNow(kind);
    } else {
      _playNow('move');
    }
  }

  void dispose() {
    _disposed = true;

    final unique = _pools.values.toSet();

    _pools.clear();

    for (final pool in unique) {
      unawaited(pool.dispose());
    }
  }
}

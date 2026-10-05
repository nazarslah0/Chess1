import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// أصوات الشطرنج (MP3).
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
    'move': 'sounds/move.mp3',
    'capture': 'sounds/take.mp3',
    'check': 'sounds/snap.mp3',
    'checkmate': 'sounds/snap.mp3',
    'castle': 'sounds/swap.mp3',
    'promotion': 'sounds/swap.mp3',
    'game_over': 'sounds/rewind.mp3',
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
    // ملفات متكررة (check/checkmate، castle/promotion) تشارك Pool واحدة.
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

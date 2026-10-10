import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lc0/lc0.dart';
import 'package:path_provider/path_provider.dart';

import 'maia_service.dart' show MaiaService;

/// ينسخ ملف الأوزان من الـ assets إلى مجلد التطبيق (lc0 يحتاج مسار
/// ملف حقيقي). يعيد null إن لم يكن الملف مضمَّنًا.
Future<String?> _materializeMaia(int bucket) async {
  try {
    final data = await rootBundle.load(MaiaService.assetPath(bucket));

    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/maia/maia-$bucket.pb.gz');

    if (await file.exists() && await file.length() == bytes.length) {
      return file.path;
    }

    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  } catch (_) {
    return null;
  }
}

/// جلسة Maia واحدة بأوزان مستوى واحد. lc0 يسمح بمحرك واحد حي في كل
/// وقت، فأغلق الجلسة قبل فتح أخرى.
class MaiaSession {
  final Lc0 _engine;

  StreamSubscription<String>? _sub;
  void Function(String line)? _onLine;

  MaiaSession._(this._engine);

  /// lc0 يسمح بمحرك حي واحد فقط؛ نمنع فتح جلسة جديدة قبل اكتمال
  /// إغلاق السابقة (مثلًا عند الانتقال بين شاشتين).
  static Future<void> _pendingClose = Future<void>.value();

  static final RegExp _moveLine = RegExp(
    r'info string (\S+)\s+\(\s*\d+\s*\)\s+N:.*?\(P:\s*([\d.]+)%\)',
  );

  static Future<MaiaSession?> open(int bucket) async {
    await _pendingClose;

    final path = await _materializeMaia(bucket);

    if (path == null) return null;

    Lc0? engine;

    try {
      engine = await Lc0.create();

      final session = MaiaSession._(engine);

      session._sub = engine.stdout.listen(session._dispatch);

      engine.stdin = 'setoption name WeightsFile value $path';
      engine.stdin = 'setoption name VerboseMoveStats value true';
      engine.stdin = 'setoption name Threads value 1';

      final ready = Completer<bool>();

      session._onLine = (line) {
        if (line == 'readyok' && !ready.isCompleted) {
          ready.complete(true);
        }
      };

      engine.stdin = 'isready';

      final ok = await ready.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => false,
      );

      session._onLine = null;

      if (!ok) {
        await session.close();
        return null;
      }

      return session;
    } catch (_) {
      try {
        await engine?.dispose();
      } catch (_) {}

      return null;
    }
  }

  void _dispatch(String line) => _onLine?.call(line.trim());

  /// احتمال كل نقلة (UCI → 0..1) عند لاعب هذا المستوى. نمرّر كل
  /// نقلات المباراة السابقة (وليس FEN فقط) لأن Maia دُرِّبت على
  /// وضعيات مع تاريخها، فدقتها أعلى معها.
  Future<Map<String, double>?> policy({
    required String startFen,
    required List<String> movesUci,
  }) async {
    final result = <String, double>{};
    final done = Completer<bool>();

    _onLine = (line) {
      final m = _moveLine.firstMatch(line);

      if (m != null) {
        result[m.group(1)!] =
            (double.tryParse(m.group(2)!) ?? 0) / 100.0;
        return;
      }

      if (line.startsWith('bestmove') && !done.isCompleted) {
        done.complete(true);
      }
    };

    try {
      _engine.stdin = 'position fen $startFen'
          '${movesUci.isEmpty ? '' : ' moves ${movesUci.join(' ')}'}';
      _engine.stdin = 'go nodes 1';

      final ok = await done.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );

      return ok && result.isNotEmpty ? result : null;
    } catch (_) {
      return null;
    } finally {
      _onLine = null;
    }
  }

  Future<void> close() {
    final f = _closeInner();

    _pendingClose = f;

    return f;
  }

  Future<void> _closeInner() async {
    try {
      await _sub?.cancel();
    } catch (_) {}

    _sub = null;

    try {
      await _engine.dispose();
    } catch (_) {}
  }
}

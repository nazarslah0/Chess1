import 'dart:async';

/// نسخة الويب من [MaiaSession]: Maia تحتاج lc0 عبر FFI وهو غير متاح في
/// المتصفح، فتعيد open() القيمة null دائمًا (والمستدعون يتخطون Maia).
class MaiaSession {
  MaiaSession._();

  static Future<MaiaSession?> open(int bucket) async => null;

  Future<Map<String, double>?> policy({
    required String startFen,
    required List<String> movesUci,
  }) async =>
      null;

  Future<void> close() async {}
}

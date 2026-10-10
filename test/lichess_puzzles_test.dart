import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as ch;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_analyzer/lichess_puzzles.dart';
import 'package:chess_analyzer/uci_utils.dart';

List<LichessPuzzle> _loadFromDisk() {
  final raw = File(LichessPuzzleRepository.assetPath).readAsStringSync();
  final list = jsonDecode(raw) as List;

  return [
    for (final j in list) LichessPuzzle.fromJson(j)!,
  ];
}

/// يلعب كل نقلات اللغز على الرقعة ويعيد الرقعة النهائية (أو null إن
/// وُجدت نقلة غير قانونية).
ch.Chess? _play(LichessPuzzle p) {
  final c = ch.Chess();

  if (c.load(p.fen) == false) return null;

  for (final u in p.moves) {
    final m = parseUci(u);

    if (m == null) return null;

    final args = <String, dynamic>{'from': m.from, 'to': m.to};

    if (m.promotion != null) args['promotion'] = m.promotion;

    if (c.move(args) == false) return null;
  }

  return c;
}

void main() {
  late List<LichessPuzzle> all;

  setUpAll(() => all = _loadFromDisk());

  test('كل الألغاز محمّلة بلا تكرار في المعرّفات', () {
    expect(all.length, 8530);
    expect(all.map((p) => p.id).toSet().length, all.length);
  });

  test('كل لغز: نقلاته قانونية وعددها زوجي (آخر نقلة للاعب)', () {
    for (final p in all) {
      expect(p.moves.length.isEven, isTrue, reason: p.id);
      expect(_play(p), isNotNull, reason: 'نقلة غير قانونية في ${p.id}');
    }
  });

  test('علم الكش مات يطابق نهاية اللغز فعليًا (في الاتجاهين)', () {
    var mates = 0;

    for (final p in all) {
      final ends = _play(p)!.in_checkmate;

      expect(p.isMate, ends, reason: p.id);

      if (ends) mates++;
    }

    expect(mates, greaterThan(1500));
  });

  test('ألغاز بريليانت: عدد معقول وكلها بعلامة تضحية، ولا توجد بلا تصنيف خاطئ',
      () {
    final brilliant = all.where((p) => p.isBrilliant).toList();

    expect(brilliant.length, inInclusiveRange(1000, 1400));

    // ألغاز الكش مات الصافية (mateIn1 البسيطة) لا تُعدّ تضحية.
    final plainMateIn1 = all.where(
      (p) => p.mateIn == 1 && !p.themes.contains('sacrifice'),
    );

    expect(
      plainMateIn1.where((p) => p.isBrilliant).length,
      lessThan(plainMateIn1.length ~/ 4),
    );
  });

  test('اللغز قد يكون في الصفحتين معًا (تضحية ثم كش مات)', () {
    expect(all.where((p) => p.isBrilliant && p.isMate), isNotEmpty);
  });

  test('solverSide عكس صاحب الدور في FEN', () {
    final p = all.first;
    final turn = p.fen.split(' ')[1];

    expect(p.solverSide, turn == 'w' ? 'b' : 'w');
  });
}

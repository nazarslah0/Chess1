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
    expect(all.length, 4925);
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

    expect(mates, greaterThan(1000));
  });

  test('كل الألغاز قوية: تضحية، وتقييم عالٍ، وأكثر من نقلة للاعب غالبًا', () {
    expect(all.every((p) => p.isBrilliant), isTrue);
    expect(all.every((p) => p.rating >= 2000), isTrue);

    final multi = all.where((p) => p.moves.length >= 6).length;

    expect(multi, greaterThan(all.length ~/ 2));
  });

  test('المستويات: 50 لغزًا في كل مستوى عدا الأخير (كامل) في كل صفحة', () {
    for (final lv in List.generate(7, (i) => i)) {
      final b = all.where((p) => p.levelBrilliant == lv).length;
      final m = all.where((p) => p.levelMate == lv).length;

      if (lv < 6) {
        expect(b, 50, reason: 'بريليانت مستوى $lv');
        expect(m, 50, reason: 'جيك ميت مستوى $lv');
      } else {
        expect(b, 4038);
        expect(m, 895);
      }
    }

    // ألغاز صفحة جيك ميت كلها تنتهي بكش مات.
    expect(all.where((p) => p.levelMate >= 0).every((p) => p.isMate), isTrue);
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

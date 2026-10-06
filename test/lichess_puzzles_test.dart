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

  test('الألف لغز كلها محمّلة', () {
    expect(all.length, 1000);
    expect(all.map((p) => p.id).toSet().length, 1000);
  });

  test('كل لغز: نقلاته قانونية وعددها زوجي (آخر نقلة للاعب)', () {
    for (final p in all) {
      expect(p.moves.length.isEven, isTrue, reason: p.id);
      expect(_play(p), isNotNull, reason: 'نقلة غير قانونية في ${p.id}');
    }
  });

  test('ألغاز جيك ميت تنتهي بكش مات فعلًا', () {
    final mates = all.where((p) => p.category == PuzzleCategory.mate);

    expect(mates, isNotEmpty);

    for (final p in mates) {
      expect(_play(p)!.in_checkmate, isTrue, reason: p.id);
    }
  });

  test('التصنيف: mate ↔ ثيم mate، والباقي بريليانت', () {
    for (final p in all) {
      final hasMate = p.themes.contains('mate');

      expect(
        p.category,
        hasMate ? PuzzleCategory.mate : PuzzleCategory.brilliant,
        reason: p.id,
      );
    }

    expect(
      all.where((p) => p.category == PuzzleCategory.mate).length +
          all.where((p) => p.category == PuzzleCategory.brilliant).length,
      1000,
    );
  });

  test('solverSide عكس صاحب الدور في FEN', () {
    final p = all.first;
    final turn = p.fen.split(' ')[1];

    expect(p.solverSide, turn == 'w' ? 'b' : 'w');
  });
}

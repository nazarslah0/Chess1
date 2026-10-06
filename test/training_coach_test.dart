import 'package:flutter_test/flutter_test.dart';

import 'package:chess_analyzer/game_review_models.dart';
import 'package:chess_analyzer/models.dart';
import 'package:chess_analyzer/training_coach.dart';

PositionEval _eval(int cp, String best, {int? second}) => PositionEval(
      cpWhite: cp,
      label: '$cp',
      bestUci: best,
      pv: <String>[best],
      secondCpWhite: second,
      depth: 12,
    );

void main() {
  group('trainingPhase / effectiveMinLoss', () {
    test('المراحل', () {
      expect(trainingPhase(GameState.startFen, 0), 'opening');
      expect(trainingPhase('8/8/4k3/8/8/4K3/4P3/8 w - - 0 50', 80),
          'endgame');
    });

    test('الحد الأدنى يتكيّف', () {
      int f(String phase, bool tac, int ev) => effectiveMinLoss(
            baseCp: 50,
            phase: phase,
            tactical: tac,
            moverEvalBeforeCp: ev,
          );

      expect(f('middlegame', false, 0), 50);
      expect(f('endgame', false, 0), 40);
      expect(f('middlegame', false, 800), 100);
    });
  });

  group('judgeMove', () {
    const start = GameState.startFen;

    test('أفضل نقلة', () {
      final j = judgeMove(
        fenBefore: start,
        playedUci: 'e2e4',
        color: 'w',
        ply: 0,
        before: _eval(30, 'e2e4'),
        after: null,
        minLossCp: 50,
      );

      expect(j.kind, CoachKind.best);
      expect(j.hasStrongerMove, isFalse);
    });

    test('خطأ فادح يظهر كبطاقة حمراء', () {
      final j = judgeMove(
        fenBefore: start,
        playedUci: 'a2a3',
        color: 'w',
        ply: 0,
        before: _eval(30, 'e2e4'),
        after: _eval(-250, 'e7e5'),
        minLossCp: 50,
      );

      expect(j.kind, CoachKind.severe);
      expect(j.quality, MoveQuality.blunder);
      expect(j.bestUci, 'e2e4');
    });

    test('فرق صغير لا تظهر له رسالة', () {
      final j = judgeMove(
        fenBefore: start,
        playedUci: 'a2a3',
        color: 'w',
        ply: 0,
        before: _eval(30, 'e2e4'),
        after: _eval(-10, 'e7e5'),
        minLossCp: 50,
      );

      expect(j.hasStrongerMove, isFalse);
    });
  });
}

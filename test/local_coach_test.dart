import 'package:flutter_test/flutter_test.dart';

import 'package:chess_analyzer/coach_models.dart';
import 'package:chess_analyzer/coach_prompts.dart';
import 'package:chess_analyzer/coach_session.dart';
import 'package:chess_analyzer/coach_templates.dart';
import 'package:chess_analyzer/game_review_models.dart';

CoachMoveInput _input(MoveQuality q) => CoachMoveInput(
      moveNumber: 12,
      side: 'white',
      san: 'Nf5',
      quality: q,
      evalBefore: 1.8,
      evalAfter: 0.6,
      evalLoss: 1.2,
      bestMove: 'Bg5',
      principalVariation: const ['Bg5', 'Qd7', 'Rad1'],
      phase: 'middlegame',
      tablebaseVerdict: null,
      isCritical: false,
    );

void main() {
  group('CoachPromptEngine', () {
    test('يستخرج JSON حتى مع ``` و <think>', () {
      const raw = '<think>hmm</think>```json\n'
          '{"title":"t","summary":"s","explanation":"e","lesson":"l"}\n```';

      final m = CoachPromptEngine.extractJson(raw);

      expect(m, isNotNull);
      expect(m!['summary'], 's');
    });

    test('يقبل نقلات مسموحة ويفرض betterMove من المحرك', () {
      const raw = '{"title":"t","summary":"لعبت Nf5 وهي غير دقيقة",'
          '"explanation":"كانت Bg5 أقوى","betterMove":"Qh5",'
          '"lesson":"l"}';

      final e = CoachPromptEngine.parse(
        raw,
        allowedMoves: const {'Nf5', 'Bg5'},
        trustedBetterMove: 'Bg5',
      );

      expect(e, isNotNull);
      expect(e!.betterMove, 'Bg5');
      expect(e.fromModel, isTrue);
    });

    test('يرفض نقلة لم يزوّد بها المحرك', () {
      const raw = '{"title":"t","summary":"s",'
          '"explanation":"العب Qh5 مباشرة","lesson":"l"}';

      final e = CoachPromptEngine.parse(
        raw,
        allowedMoves: const {'Nf5'},
      );

      expect(e, isNull);
    });

    test('JSON تالف = null (يعود المدرب للقوالب)', () {
      expect(
        CoachPromptEngine.parse('not json', allowedMoves: const {}),
        isNull,
      );
    });
  });

  group('CoachTemplateEngine', () {
    test('لا يكشف أفضل نقلة في وضع التدريب', () {
      final e = CoachTemplateEngine.explainMove(
        _input(MoveQuality.mistake),
        level: CoachLevel.intermediate,
        lang: CoachLang.ar,
      );

      expect(e.betterMove, isNull);
      expect(e.explanation.contains('Bg5'), isFalse);
    });

    test('يكشفها عند الطلب ويدعم الإنجليزية', () {
      final e = CoachTemplateEngine.explainMove(
        _input(MoveQuality.blunder),
        level: CoachLevel.advanced,
        lang: CoachLang.en,
        revealBest: true,
      );

      expect(e.betterMove, 'Bg5');
      expect(e.explanation.contains('Bg5'), isTrue);
    });
  });

  group('CoachSessionStore', () {
    test('نصيحة شخصية عند تركّز الأخطاء في الافتتاح', () {
      final store = CoachSessionStore.instance;

      store.session = CoachSession()
        ..games = 5
        ..moves = 100
        ..inaccuracies = 8
        ..errorsByPhase['opening'] = 6
        ..errorsByPhase['middlegame'] = 2;

      expect(store.insights(CoachLang.ar), isNotEmpty);
    });
  });
}

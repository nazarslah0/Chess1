import 'dart:async';

import 'package:chess/chess.dart' as ch;

import 'analysis_result.dart';
import 'analysis_rules.dart';
import 'engine_service.dart';
import 'game_review_models.dart';
import 'lichess_data_service.dart';
import 'pv_utils.dart';
import 'uci_utils.dart';

// ================================================================
// «التدريب الذكي أثناء المباراة» — المنطق (بلا واجهة).
//
// - [TrainingAnalyzer]: يحلّل وضعية بنسخة Stockfish الموجودة (نفس
//   EngineService) ويُلغي أي تحليل سابق قبل البدء (لا تتراكم أوامر).
// - [judgeMove]: يقارن النقلة المُلعَبة بأفضل نقلة للمحرك ويصنّفها،
//   مع حدّ أدنى للخسارة يتكيّف مع المرحلة والتكتيك والتفوّق الحاسم،
//   ومع Tablebase (فوز/تعادل/خسارة) عند توفره.
// - كل نقلة UCI تُحلَّل عبر parseUci() فقط (لا SAN ولا نص PV).
// ================================================================

/// ما قاله Stockfish عن وضعية واحدة.
class PositionEval {
  /// التقييم من منظور الأبيض بالسنتيبون (المات = ±10000).
  final int cpWhite;

  /// نص التقييم (مثل +0.42 أو M3).
  final String label;

  /// أفضل نقلة من سطر `bestmove` الحقيقي (UCI) أو null.
  final String? bestUci;

  /// الخط الرئيسي (UCI) من أول سطر MultiPV.
  final List<String> pv;

  /// تقييم ثاني أفضل خط (منظور الأبيض) إن توفر.
  final int? secondCpWhite;

  final int depth;

  const PositionEval({
    required this.cpWhite,
    required this.label,
    required this.bestUci,
    required this.pv,
    required this.secondCpWhite,
    required this.depth,
  });
}

int _cpOf(PvLine line) =>
    (line.evalPawns * 100).round().clamp(-10000, 10000);

/// يحلّل الوضعيات للتدريب باستخدام [EngineService] واحد.
class TrainingAnalyzer {
  TrainingAnalyzer(
    this.engine, {
    this.movetimeMs = 450,
    this.depth = 18,
  });

  final EngineService engine;
  final int movetimeMs;
  final int depth;

  int _token = 0;
  Completer<PositionEval?>? _active;

  bool get busy => _active != null;

  /// يُلغي التحليل الجاري (إن وُجد) فلا تُقبل نتائجه.
  void cancel({bool stopEngine = true}) {
    _token++;

    final c = _active;

    _active = null;

    if (c != null && !c.isCompleted) c.complete(null);

    if (stopEngine && engine.analyzing) {
      unawaited(engine.stop());
    }
  }

  /// يحلّل [fen] ويعيد نتيجته، أو null عند الإلغاء/الفشل/المهلة.
  Future<PositionEval?> analyze(String fen) async {
    // EngineService.analyze يوقف البحث السابق بنفسه.
    cancel(stopEngine: false);

    final token = _token;
    final completer = Completer<PositionEval?>();

    _active = completer;

    final lines = <int, PvLine>{};

    engine.onInfo = (multipv, line) {
      if (token != _token) return;

      lines[multipv] = line;
    };

    engine.onBestMove = (uci) {
      if (token != _token || completer.isCompleted) return;

      final first = lines[1];

      if (first == null) {
        completer.complete(null);

        return;
      }

      final second = lines[2];

      completer.complete(
        PositionEval(
          cpWhite: _cpOf(first),
          label: first.evalLabel,
          bestUci: parseUci(uci)?.uci,
          pv: first.uciMoves,
          secondCpWhite: second == null ? null : _cpOf(second),
          depth: first.depth,
        ),
      );
    };

    AnalysisRequest? request;

    try {
      request = await engine.analyze(
        fen,
        depth: depth,
        multiPv: 2,
        movetimeMs: movetimeMs,
      );
    } catch (_) {
      request = null;
    }

    if (request == null && !completer.isCompleted) {
      completer.complete(null);
    }

    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );

    if (identical(_active, completer)) {
      _active = null;

      // انتهت المهلة بلا نتيجة: لا نترك المحرك يبحث.
      if (result == null && engine.analyzing) {
        unawaited(engine.stop());
      }
    }

    return result;
  }
}

// ================================================================
// الحكم على النقلة
// ================================================================

/// نوع رد المدرب على النقلة.
enum CoachKind {
  /// أفضل نقلة: 🟢 أفضل نقلة!
  best,

  /// قريبة جدًا من الأفضل: 🟢 ممتاز!
  excellent,

  /// لا رسالة (نقلة جيدة والفرق أقل من الحد الأدنى، أو نقلة إجبارية).
  silent,

  /// نقلة جيدة لكن توجد أقوى: 💡
  soft,

  /// خطأ / خطأ فادح / فرصة ضائعة: 🔴
  severe,
}

class MoveJudgement {
  final MoveQuality quality;
  final CoachKind kind;

  /// خسارة النقلة بالسنتيبون من منظور من لعبها (مقيّدة ±1000).
  final int lossCp;

  /// الحد الأدنى المطبَّق فعليًا بعد مراعاة المرحلة والتكتيك.
  final int effectiveMinLossCp;

  /// أفضل نقلة (UCI) من Stockfish (أو Tablebase في النهايات).
  final String? bestUci;
  final List<String> pv;
  final bool onlyMove;
  final String? tablebaseVerdict;
  final String phase;

  final int evalBeforeWhiteCp;
  final int evalAfterWhiteCp;
  final int? gapCp;
  final int? tbWdlBeforeWhite;
  final int? tbWdlAfterWhite;
  final bool playedWasBest;

  const MoveJudgement({
    required this.quality,
    required this.kind,
    required this.lossCp,
    required this.effectiveMinLossCp,
    required this.bestUci,
    required this.pv,
    required this.onlyMove,
    required this.tablebaseVerdict,
    required this.phase,
    required this.evalBeforeWhiteCp,
    required this.evalAfterWhiteCp,
    required this.gapCp,
    required this.tbWdlBeforeWhite,
    required this.tbWdlAfterWhite,
    required this.playedWasBest,
  });

  bool get hasStrongerMove =>
      kind == CoachKind.soft || kind == CoachKind.severe;
}

int _clampCp(int cp) => cp.clamp(-1000, 1000);

/// عدد النقلات القانونية في [fen] (99 إن تعذّر القراءة).
int legalMoveCount(String fen) {
  final g = ch.Chess();

  try {
    if (g.load(fen) == false) return 99;

    return g.moves().length;
  } catch (_) {
    return 99;
  }
}

/// مرحلة المباراة من المادة المتبقية (بدون البيادق) وعدد الأنصاف.
String trainingPhase(String fen, int ply) {
  final board = fen.trim().split(' ').first;

  var material = 0;

  for (final u in board.runes) {
    switch (String.fromCharCode(u).toLowerCase()) {
      case 'q':
        material += 9;
      case 'r':
        material += 5;
      case 'b':
      case 'n':
        material += 3;
      default:
        break;
    }
  }

  if (material <= 26) return 'endgame';

  if (ply < 20 && material >= 50) return 'opening';

  return 'middlegame';
}

/// الحد الأدنى الفعّال للخسارة: القيمة التي اختارها المستخدم مضروبة
/// بعامل يراعي المرحلة والتكتيك والتفوّق الحاسم.
int effectiveMinLoss({
  required int baseCp,
  required String phase,
  required bool tactical,
  required int moverEvalBeforeCp,
}) {
  var f = 1.0;

  if (phase == 'opening') f *= 1.2;
  if (phase == 'endgame') f *= 0.8;
  if (tactical) f *= 0.85;

  // متفوّق (أو متأخر) بفارق حاسم: الفروق الصغيرة لا تغيّر النتيجة.
  if (moverEvalBeforeCp.abs() >= 700) f *= 2.0;

  return (baseCp * f).round().clamp(10, 400);
}

/// يحكم على نقلة المستخدم.
///
/// [color]: لون من لعب النقلة ('w' / 'b').
/// [ply]: رقم نصف النقلة (من 0).
/// [before]: تحليل الوضعية قبل النقلة، [after]: بعدها.
/// [tbBefore]: تفاصيل Tablebase قبل النقلة إن توفرت.
MoveJudgement judgeMove({
  required String fenBefore,
  required String playedUci,
  required String color,
  required int ply,
  required PositionEval before,
  required PositionEval? after,
  required int minLossCp,
  TablebaseDetail? tbBefore,
}) {
  final sign = color == 'w' ? 1 : -1;

  final phase = trainingPhase(fenBefore, ply);

  var bestUci = before.bestUci;

  final sameBest = isSameUciMove(playedUci, bestUci);

  final beforeW = before.cpWhite;
  final afterW = sameBest ? (after?.cpWhite ?? beforeW) : after?.cpWhite;

  // لا نعرف تقييم ما بعد النقلة: لا نحكم (لا رسالة).
  if (afterW == null) {
    return MoveJudgement(
      quality: MoveQuality.good,
      kind: CoachKind.silent,
      lossCp: 0,
      effectiveMinLossCp: minLossCp,
      bestUci: bestUci,
      pv: before.pv,
      onlyMove: false,
      tablebaseVerdict: null,
      phase: phase,
      evalBeforeWhiteCp: beforeW,
      evalAfterWhiteCp: beforeW,
      gapCp: null,
      tbWdlBeforeWhite: null,
      tbWdlAfterWhite: null,
      playedWasBest: false,
    );
  }

  // نقلة إجبارية (الوحيدة القانونية): لا تُعدّ خطأ ولا تستحق مديحًا.
  final forced = legalMoveCount(fenBefore) == 1;

  var loss = sameBest
      ? 0
      : (_clampCp(beforeW * sign) - _clampCp(afterW * sign))
          .clamp(0, 1000);

  // الفارق بين أفضل خط وثانيه (منظور من لعب).
  final second = before.secondCpWhite;

  final gap = second == null
      ? null
      : ((_clampCp(beforeW * sign) - _clampCp(second * sign))
          .clamp(0, 2000));

  final bestSan = bestUci == null ? '' : pvToSan(fenBefore, [bestUci]);

  final tactical = bestSan.contains('x') ||
      bestSan.contains('+') ||
      bestSan.contains('=') ||
      bestSan.contains('#');

  var quality = classifyMove(
    cpBeforeWhite: _clampCp(beforeW),
    cpAfterWhite: _clampCp(afterW),
    color: color,
    wasBestMove: sameBest,
    onlyLegalMove: forced,
  );

  // ---------------- Tablebase: النتيجة أهم من السنتيبون ----------------
  String? tbVerdict;
  int? tbBeforeW;
  int? tbAfterW;
  var tbWorse = false;
  var tbSame = false;

  if (tbBefore != null && tbBefore.result != null && !forced) {
    final tbMove = tbBefore.moves
        .where((m) => isSameUciMove(m.uci, playedUci))
        .toList();

    final playedRes = tbMove.isEmpty ? null : tbMove.first.result;

    if (playedRes != null) {
      final bestRes = tbBefore.result!;

      tbBeforeW = bestRes * sign;
      tbAfterW = playedRes * sign;

      quality = applyTablebaseClassification(
        quality: quality,
        color: color,
        wdlBeforeWhite: tbBeforeW,
        wdlAfterWhite: tbAfterW,
      );

      tbVerdict = tablebaseVerdict(
        side: color,
        wdlBeforeWhite: tbBeforeW,
        wdlAfterWhite: tbAfterW,
      );

      if (playedRes < bestRes) {
        tbWorse = true;

        if (loss < 100) loss = 100;

        // أفضل نقلة: نقلة المحرك إن حافظت على النتيجة، وإلا
        // أول نقلة Tablebase تحافظ عليها.
        final engineKeeps = tbBefore.moves.any(
          (m) => isSameUciMove(m.uci, bestUci) && m.result == bestRes,
        );

        if (!engineKeeps) {
          final keep = tbBefore.moves
              .where((m) => m.result == bestRes)
              .toList();

          if (keep.isNotEmpty) bestUci = parseUci(keep.first.uci)?.uci;
        }
      } else {
        tbSame = true;
        loss = 0;
      }
    }
  }

  final moverEvalBefore = _clampCp(beforeW * sign);

  final effMin = effectiveMinLoss(
    baseCp: minLossCp,
    phase: phase,
    tactical: tactical,
    moverEvalBeforeCp: moverEvalBefore,
  );

  // فرق صغير: لا نعاقب اللاعب.
  if (!tbWorse &&
      loss < effMin &&
      (quality == MoveQuality.inaccuracy ||
          quality == MoveQuality.mistake ||
          quality == MoveQuality.blunder)) {
    quality = MoveQuality.good;
  }

  final isErr = quality == MoveQuality.mistake ||
      quality == MoveQuality.blunder ||
      quality == MoveQuality.miss;

  CoachKind kind;

  if (forced) {
    kind = CoachKind.silent;
  } else if (sameBest || quality == MoveQuality.best) {
    kind = CoachKind.best;
  } else if (tbWorse || (loss >= effMin && !tbSame)) {
    kind = isErr || tbWorse ? CoachKind.severe : CoachKind.soft;
  } else if (quality == MoveQuality.excellent || loss <= 10) {
    kind = CoachKind.excellent;
  } else {
    kind = CoachKind.silent;
  }

  final onlyMove = gap != null &&
      gap >= 150 &&
      !sameBest &&
      kind != CoachKind.silent &&
      kind != CoachKind.excellent;

  return MoveJudgement(
    quality: quality,
    kind: kind,
    lossCp: loss,
    effectiveMinLossCp: effMin,
    bestUci: bestUci,
    pv: before.pv,
    onlyMove: onlyMove,
    tablebaseVerdict: tbVerdict,
    phase: phase,
    evalBeforeWhiteCp: beforeW,
    evalAfterWhiteCp: afterW,
    gapCp: gap,
    tbWdlBeforeWhite: tbBeforeW,
    tbWdlAfterWhite: tbAfterW,
    playedWasBest: sameBest,
  );
}

// ================================================================
// بيانات التدريب لكل نقلة + الملخص
// ================================================================

/// سجل تدريب نقلة واحدة للمستخدم: [result] هو MoveAnalysisResult
/// الموسَّع بحقول التدريب (playedMove / bestMove / evaluationBefore /
/// evaluationAfter / evaluationLoss / classification / hintShown /
/// hintLevel / solutionShown / bestMoveTried / trainingCompleted).
class TrainingEntry {
  final MoveAnalysisResult result;

  /// تصنيف المحاولة الأولى (قبل أي «حاول مرة أخرى»).
  final MoveQuality firstQuality;

  /// هل ظهرت للاعب رسالة «هناك نقلة أقوى»؟
  final bool coached;

  /// هل لعب أفضل نقلة من المحاولة الأولى؟
  final bool firstTryBest;

  const TrainingEntry({
    required this.result,
    required this.firstQuality,
    required this.coached,
    required this.firstTryBest,
  });

  TrainingEntry copyWith({MoveAnalysisResult? result}) => TrainingEntry(
        result: result ?? this.result,
        firstQuality: firstQuality,
        coached: coached,
        firstTryBest: firstTryBest,
      );
}

/// يبني [MoveAnalysisResult] من الحكم على النقلة.
MoveAnalysisResult buildTrainingResult({
  required int ply,
  required String color,
  required String san,
  required String playedUci,
  required String fenBefore,
  required String fenAfter,
  required MoveJudgement j,
  bool hintShown = false,
  int hintLevel = 0,
  bool solutionShown = false,
  bool bestMoveTried = false,
  bool trainingCompleted = false,
}) {
  final sign = color == 'w' ? 1 : -1;

  final best = j.bestUci ?? '';

  final epBefore = expectedPointsFromCp(
    _clampCp(j.evalBeforeWhiteCp),
    perspective: color,
  );

  final epAfter = expectedPointsFromCp(
    _clampCp(j.evalAfterWhiteCp),
    perspective: color,
  );

  return MoveAnalysisResult(
    ply: ply,
    moveNumber: ply ~/ 2 + 1,
    side: color,
    san: san,
    uci: playedUci,
    fenBefore: fenBefore,
    fenAfter: fenAfter,
    evaluationBeforeCp: _clampCp(j.evalBeforeWhiteCp) * sign,
    evaluationAfterCp: _clampCp(j.evalAfterWhiteCp) * sign,
    evaluationLossCp: j.lossCp,
    evaluationBeforeWhiteCp: j.evalBeforeWhiteCp,
    evaluationAfterWhiteCp: j.evalAfterWhiteCp,
    expectedPointsBefore: epBefore,
    expectedPointsAfter: epAfter,
    expectedPointsLoss: (epBefore - epAfter).clamp(0.0, 1.0).toDouble(),
    bestMoveSan: best.isEmpty ? '' : pvToSan(fenBefore, [best]),
    bestMoveUci: best,
    principalVariationUci: j.pv,
    classification: j.quality,
    phase: j.phase,
    materialBefore: 0,
    materialAfter: 0,
    isCritical: false,
    isBestMove: j.playedWasBest,
    isBrilliant: false,
    isMistake: j.quality == MoveQuality.mistake,
    isBlunder: j.quality == MoveQuality.blunder,
    isMissedOpportunity: j.quality == MoveQuality.miss,
    tablebaseVerdict: j.tablebaseVerdict,
    bestMoveGapCp: j.gapCp,
    tablebaseWdlBeforeWhite: j.tbWdlBeforeWhite,
    tablebaseWdlAfterWhite: j.tbWdlAfterWhite,
    hintShown: hintShown,
    hintLevel: hintLevel,
    solutionShown: solutionShown,
    bestMoveTried: bestMoveTried,
    trainingCompleted: trainingCompleted,
  );
}

/// ملخص «🎓 أداؤك في التدريب» بعد انتهاء المباراة.
class TrainingSummary {
  /// نقلات قوية وجدها اللاعب بنفسه (أفضل نقلة من أول محاولة، أو
  /// بعد «حاول مرة أخرى» بلا تلميح).
  final int foundBySelf;

  /// احتاج تلميحًا (سهمًا) ولم يرَ الحل.
  final int neededHint;

  /// شاهد الحل.
  final int sawSolution;

  /// نقلات أولى صُنّفت خطأ / خطأ فادح / فرصة ضائعة.
  final int mistakes;

  /// عدد المواضع التي ظهر فيها للاعب «هناك نقلة أقوى».
  final int coachedMoments;

  /// مواضع ظهرت فيها نقلة أقوى وتابع اللاعب دون حلّها أو تلميح.
  final int unresolved;

  const TrainingSummary({
    required this.foundBySelf,
    required this.neededHint,
    required this.sawSolution,
    required this.mistakes,
    required this.coachedMoments,
    required this.unresolved,
  });

  int get strongMoments =>
      foundBySelf + neededHint + sawSolution + unresolved;

  /// نسبة النقلات القوية التي وجدها بنفسه (0..100) أو null.
  int? get percentFoundBySelf {
    final total = strongMoments;

    if (total == 0) return null;

    return (foundBySelf * 100 / total).round();
  }

  bool get isEmpty =>
      foundBySelf == 0 &&
      neededHint == 0 &&
      sawSolution == 0 &&
      mistakes == 0 &&
      coachedMoments == 0;

  static TrainingSummary from(Iterable<TrainingEntry> entries) {
    var self = 0;
    var hint = 0;
    var sol = 0;
    var mistakes = 0;
    var coached = 0;
    var unresolved = 0;

    for (final e in entries) {
      final r = e.result;

      if (e.firstQuality == MoveQuality.mistake ||
          e.firstQuality == MoveQuality.blunder ||
          e.firstQuality == MoveQuality.miss) {
        mistakes++;
      }

      if (!e.coached) {
        if (e.firstTryBest) self++;

        continue;
      }

      coached++;

      if (r.solutionShown) {
        sol++;
      } else if (r.hintShown) {
        hint++;
      } else if (r.trainingCompleted) {
        self++;
      } else {
        unresolved++;
      }
    }

    return TrainingSummary(
      foundBySelf: self,
      neededHint: hint,
      sawSolution: sol,
      mistakes: mistakes,
      coachedMoments: coached,
      unresolved: unresolved,
    );
  }
}

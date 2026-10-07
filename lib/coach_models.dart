import 'analysis_result.dart';
import 'game_review_models.dart';
import 'pv_utils.dart';

// ================================================================
// نماذج «المدرب المحلي» (Local AI Chess Coach).
//
// المحرك (Stockfish) = الحساب. النموذج اللغوي المحلي = الشرح فقط.
// كل الأرقام والنقلات والتصنيف تأتي من MoveAnalysisResult (المحرك)،
// والنموذج لا يقرر أي منها.
// ================================================================

enum CoachLevel { beginner, intermediate, advanced, expert }

enum CoachLang { ar, en }

CoachLevel coachLevelFromName(String? name) {
  for (final l in CoachLevel.values) {
    if (l.name == name) return l;
  }

  return CoachLevel.intermediate;
}

CoachLang coachLangFromName(String? name) =>
    name == 'en' ? CoachLang.en : CoachLang.ar;

String coachLevelLabel(CoachLevel l, CoachLang lang) {
  const ar = {
    CoachLevel.beginner: 'مبتدئ',
    CoachLevel.intermediate: 'متوسط',
    CoachLevel.advanced: 'متقدم',
    CoachLevel.expert: 'خبير',
  };

  const en = {
    CoachLevel.beginner: 'Beginner',
    CoachLevel.intermediate: 'Intermediate',
    CoachLevel.advanced: 'Advanced',
    CoachLevel.expert: 'Expert',
  };

  return (lang == CoachLang.ar ? ar : en)[l]!;
}

/// شرح منظَّم (يرجعه النموذج كـ JSON أو يبنيه محرك القوالب).
class CoachExplanation {
  final String title;
  final String summary;
  final String explanation;
  final String? betterMove;
  final String? idea;
  final String lesson;

  /// true إذا ولّده النموذج اللغوي المحلي، false إذا كان قالبًا.
  final bool fromModel;

  const CoachExplanation({
    required this.title,
    required this.summary,
    required this.explanation,
    required this.lesson,
    this.betterMove,
    this.idea,
    this.fromModel = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'explanation': explanation,
        if (betterMove != null) 'betterMove': betterMove,
        if (idea != null) 'idea': idea,
        'lesson': lesson,
      };

  /// يقرأ JSON بتسامح؛ يعيد null إذا لم يحتوِ على شرح مفيد.
  static CoachExplanation? fromJson(
    Map<String, dynamic> m, {
    bool fromModel = false,
  }) {
    String? s(String k) {
      final v = m[k];

      if (v == null) return null;

      final t = v.toString().trim();

      return t.isEmpty || t == 'null' ? null : t;
    }

    final summary = s('summary');
    final explanation = s('explanation');

    if (summary == null && explanation == null) return null;

    return CoachExplanation(
      title: s('title') ?? '',
      summary: summary ?? '',
      explanation: explanation ?? '',
      betterMove: s('betterMove'),
      idea: s('idea'),
      lesson: s('lesson') ?? '',
      fromModel: fromModel,
    );
  }
}

String _qualityKey(MoveQuality q) => q.name.toUpperCase();

/// بيانات Stockfish المنظمة لنقلة واحدة (هذا فقط ما يراه النموذج).
/// التقييمات بالبيدق من منظور اللاعب الذي نفّذ النقلة
/// (موجب = جيد له).
class CoachMoveInput {
  final int moveNumber;
  final String side; // white / black
  final String fenBefore;
  final String fenAfter;
  final String san;
  final MoveQuality quality;
  final double evalBefore;
  final double evalAfter;
  final double evalLoss;
  final String bestMove; // SAN
  final List<String> principalVariation; // SAN
  final String phase;
  final String? tablebaseVerdict;
  final bool isCritical;

  const CoachMoveInput({
    required this.moveNumber,
    required this.side,
    this.fenBefore = '',
    this.fenAfter = '',
    required this.san,
    required this.quality,
    required this.evalBefore,
    required this.evalAfter,
    required this.evalLoss,
    required this.bestMove,
    required this.principalVariation,
    required this.phase,
    required this.tablebaseVerdict,
    required this.isCritical,
  });

  factory CoachMoveInput.fromResult(MoveAnalysisResult r) {
    final pv = r.principalVariationUci.isEmpty
        ? const <String>[]
        : pvToSan(r.fenBefore, r.principalVariationUci)
            .split(' ')
            .where((e) => e.isNotEmpty)
            .toList();

    return CoachMoveInput(
      moveNumber: r.moveNumber,
      side: r.side == 'w' ? 'white' : 'black',
      fenBefore: r.fenBefore,
      fenAfter: r.fenAfter,
      san: r.san,
      quality: r.classification,
      evalBefore: r.evaluationBeforeCp / 100.0,
      evalAfter: r.evaluationAfterCp / 100.0,
      evalLoss: r.evaluationLossCp / 100.0,
      bestMove: r.bestMoveSan,
      principalVariation: pv,
      phase: r.phase,
      tablebaseVerdict: r.tablebaseVerdict,
      isCritical: r.isCritical,
    );
  }

  /// بصيغة المثال في المواصفات.
  Map<String, dynamic> toJson({bool revealBest = true}) => {
        'move': san,
        'fenBefore': fenBefore,
        'fenAfter': fenAfter,
        'classification': _qualityKey(quality),
        'evaluationBefore': double.parse(evalBefore.toStringAsFixed(2)),
        'evaluationAfter': double.parse(evalAfter.toStringAsFixed(2)),
        'evaluationLoss': double.parse(evalLoss.toStringAsFixed(2)),
        if (revealBest) 'bestMove': bestMove,
        if (revealBest) 'principalVariation': principalVariation,
        'gamePhase': phase,
        'side': side,
        'critical': isCritical,

        if (tablebaseVerdict != null) 'tablebase': tablebaseVerdict,
      };

  /// كل النقلات المسموح للنموذج بذكرها.
  Set<String> allowedMoves({required bool revealBest}) => {
        san,
        if (revealBest && bestMove.isNotEmpty) bestMove,
        if (revealBest) ...principalVariation,
      };
}

/// تحليل وضعية (للمدرب: «تحليل وضعية»).
class CoachPositionInput {
  final String fen;
  final String sideToMove; // white / black
  final double evalPawns; // منظور الأبيض
  final String bestMove; // SAN
  final List<String> principalVariation; // SAN
  final String phase;

  const CoachPositionInput({
    required this.fen,
    required this.sideToMove,
    required this.evalPawns,
    required this.bestMove,
    required this.principalVariation,
    required this.phase,
  });

  Map<String, dynamic> toJson() => {
        'fen': fen,
        'sideToMove': sideToMove,
        'evaluationWhite': double.parse(evalPawns.toStringAsFixed(2)),
        'bestMove': bestMove,
        'principalVariation': principalVariation,
        'gamePhase': phase,
      };

  Set<String> allowedMoves() => {bestMove, ...principalVariation};
}

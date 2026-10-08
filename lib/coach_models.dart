import 'analysis_result.dart';
import 'game_review_models.dart';
import 'pv_utils.dart';

// ================================================================
// نماذج «مدرب الشطرنج» (جمل جاهزة).
//
// المحرك (Stockfish) = الحساب. المدرب = جمل جاهزة تُختار بحسب بيانات
// المحرك (التصنيف، التقييم، أفضل نقلة، المرحلة، نوع النقلة) ومستوى
// اللاعب ولغته. كل الأرقام والنقلات والتصنيف تأتي من MoveAnalysisResult.
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

/// شرح منظَّم تبنيه [CoachTemplateEngine].
class CoachExplanation {
  final String title;
  final String summary;
  final String explanation;
  final String? betterMove;
  final String? idea;
  final String lesson;

  const CoachExplanation({
    required this.title,
    required this.summary,
    required this.explanation,
    required this.lesson,
    this.betterMove,
    this.idea,
  });
}

/// بيانات Stockfish المنظمة لنقلة واحدة.
/// التقييمات بالبيدق من منظور اللاعب الذي نفّذ النقلة
/// (موجب = جيد له).
class CoachMoveInput {
  final int moveNumber;
  final String side; // white / black
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
}

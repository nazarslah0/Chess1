import 'analysis_result.dart';
import 'app_settings.dart';
import 'coach_models.dart';
import 'coach_session.dart';
import 'coach_templates.dart';
import 'game_review_models.dart';

/// واجهة المدرب: تحوّل بيانات Stockfish إلى جمل جاهزة بحسب مستوى
/// اللاعب ولغته. بدون إنترنت وبدون أي خدمة خارجية.
class CoachService {
  CoachService._();

  static final CoachService instance = CoachService._();

  CoachLevel get _level =>
      coachLevelFromName(AppSettings.instance.coachLevelName);

  CoachLang get _lang => coachLangFromName(AppSettings.instance.coachLangName);

  static bool _isHard(MoveAnalysisResult r) {
    switch (r.classification) {
      case MoveQuality.inaccuracy:
      case MoveQuality.mistake:
      case MoveQuality.miss:
      case MoveQuality.blunder:
        return true;
      default:
        return false;
    }
  }

  /// يشرح نقلة. [revealBest] = false في وضع التدريب (لا نكشف الحل).
  CoachExplanation explainMove(
    MoveAnalysisResult analysis, {
    bool revealBest = false,
    CoachLevel? level,
    CoachLang? lang,
  }) {
    final lg = lang ?? _lang;

    final facts = CoachSessionStore.instance.insights(lg);

    return CoachTemplateEngine.explainMove(
      CoachMoveInput.fromResult(analysis),
      level: level ?? _level,
      lang: lg,
      revealBest: revealBest,
      personalNote: (_isHard(analysis) && facts.isNotEmpty) ? facts.first : null,
    );
  }

  CoachExplanation explainPosition(
    CoachPositionInput analysis, {
    CoachLevel? level,
    CoachLang? lang,
  }) {
    return CoachTemplateEngine.explainPosition(
      analysis,
      level: level ?? _level,
      lang: lang ?? _lang,
    );
  }

  CoachExplanation explainGame(
    List<MoveAnalysisResult> moves, {
    CoachLevel? level,
    CoachLang? lang,
  }) {
    final lg = lang ?? _lang;

    final facts = CoachSessionStore.instance.insights(lg);

    return CoachTemplateEngine.explainGame(
      moves.map(CoachMoveInput.fromResult).toList(),
      level: level ?? _level,
      lang: lg,
      personalNote: facts.isEmpty ? null : facts.first,
    );
  }
}

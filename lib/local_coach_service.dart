import 'dart:async';

import 'package:flutter/foundation.dart';

import 'analysis_result.dart';
import 'app_settings.dart';
import 'coach_llm.dart';
import 'coach_models.dart';
import 'coach_prompts.dart';
import 'coach_session.dart';
import 'coach_templates.dart';
import 'game_review_models.dart';

enum CoachStatus {
  /// لم نفحص بعد.
  unknown,

  /// النموذج غير مثبّت (القوالب تعمل).
  notInstalled,

  downloading,

  /// مثبّت لكنه غير محمَّل في الذاكرة (تحميل كسول).
  installed,

  loading,

  /// محمَّل وجاهز.
  ready,

  error,
}

/// خدمة المدرب المحلي.
///
/// المحرك (Stockfish) يحسب، والنموذج المحلي يشرح فقط. إذا لم يتوفر
/// النموذج أو كان مشغولًا أو فشل، يعمل [CoachTemplateEngine] فورًا فلا
/// يتوقف المدرب أبدًا. كل شيء محلي: لا API ولا إنترنت (إلا لتنزيل
/// ملف النموذج مرة واحدة).
class LocalCoachService extends ChangeNotifier {
  LocalCoachService._();

  static final LocalCoachService instance = LocalCoachService._();

  /// بعد هذه المدة بلا استخدام يُحرَّر النموذج من الذاكرة.
  static const Duration idleUnload = Duration(minutes: 3);

  LocalCoachModel _model = LlamaCppCoachModel();

  CoachStatus status = CoachStatus.unknown;
  String? lastError;
  double downloadProgress = 0;

  bool _busy = false;
  Future<bool>? _loading;
  Timer? _idle;

  LocalCoachModel get model => _model;

  bool get isBusy => _busy;

  bool get isReady => status == CoachStatus.ready;

  /// استبدال النموذج (SmallModel ← BetterModel) دون تعديل بقية التطبيق.
  Future<void> useModel(LocalCoachModel m) async {
    await unload();

    _model = m;
    status = CoachStatus.unknown;

    await initialize();
  }

  void _set(CoachStatus s, {String? error}) {
    status = s;
    lastError = error;

    notifyListeners();
  }

  /// يفحص وجود النموذج فقط (لا يحمّله): App/Coach start → Check Model.
  Future<void> initialize() async {
    if (status == CoachStatus.downloading || status == CoachStatus.loading) {
      return;
    }

    try {
      if (_model.isLoaded) {
        _set(CoachStatus.ready);

        return;
      }

      _set(
        await _model.isInstalled()
            ? CoachStatus.installed
            : CoachStatus.notInstalled,
      );
    } catch (e) {
      _set(CoachStatus.error, error: '$e');
    }
  }

  /// تنزيل النموذج مرة واحدة.
  Future<bool> download() async {
    if (status == CoachStatus.downloading) return false;

    downloadProgress = 0;

    _set(CoachStatus.downloading);

    try {
      await _model.install((p) {
        downloadProgress = p.fraction;

        notifyListeners();
      });

      _set(CoachStatus.installed);

      return true;
    } catch (e) {
      _set(CoachStatus.notInstalled, error: '$e');

      return false;
    }
  }

  void cancelDownload() => _model.cancelInstall();

  Future<void> deleteModel() async {
    await _idleCancel();

    try {
      await _model.uninstall();
    } catch (_) {}

    _set(CoachStatus.notInstalled);
  }

  /// تحميل كسول: يُستدعى عند الحاجة فقط. لا يرمي أبدًا.
  Future<bool> ensureLoaded() async {
    if (status == CoachStatus.unknown) await initialize();

    if (_model.isLoaded) {
      if (status != CoachStatus.ready) _set(CoachStatus.ready);

      return true;
    }

    if (status == CoachStatus.notInstalled ||
        status == CoachStatus.downloading) {
      return false;
    }

    return _loading ??= _doLoad().whenComplete(() => _loading = null);
  }

  Future<bool> _doLoad() async {
    _set(CoachStatus.loading);

    try {
      await _model.load();

      _set(CoachStatus.ready);

      _touch();

      return true;
    } catch (e) {
      // فشل التحميل لا يُسقط التطبيق: نعود للقوالب.
      _set(CoachStatus.error, error: '$e');

      return false;
    }
  }

  void _touch() {
    _idle?.cancel();

    _idle = Timer(idleUnload, () {
      if (!_busy) unawaited(unload());
    });
  }

  Future<void> _idleCancel() async {
    _idle?.cancel();

    _idle = null;
  }

  /// يحرّر الذاكرة (يُستدعى عند الخمول أو الخروج).
  Future<void> unload() async {
    await _idleCancel();

    if (!_model.isLoaded) return;

    try {
      await _model.cancel();
      await _model.unload();
    } catch (_) {}

    if (status == CoachStatus.ready) _set(CoachStatus.installed);
  }

  /// يوقف توليدًا جاريًا (قبل أن يبدأ Stockfish عملًا ثقيلًا).
  Future<void> cancel() async {
    if (!_busy) return;

    try {
      await _model.cancel();
    } catch (_) {}
  }

  // ------------------------------------------------------------
  // الشرح
  // ------------------------------------------------------------

  static bool _isHard(MoveAnalysisResult r) {
    switch (r.classification) {
      case MoveQuality.brilliant:
      case MoveQuality.inaccuracy:
      case MoveQuality.mistake:
      case MoveQuality.miss:
      case MoveQuality.blunder:
        return true;
      default:
        return r.isCritical;
    }
  }

  CoachLevel get _level =>
      coachLevelFromName(AppSettings.instance.coachLevelName);

  CoachLang get _lang => coachLangFromName(AppSettings.instance.coachLangName);

  /// يشرح نقلة. النقلات السهلة (best/excellent/good) بقوالب محلية؛
  /// الصعبة (Brilliant/Inaccuracy/Mistake/Blunder/Missed/Critical)
  /// بالنموذج. [revealBest] = false في وضع التدريب (لا نكشف الحل).
  /// [deep] = «اشرح أكثر» (يكشف أفضل نقلة).
  Future<CoachExplanation> explainMove(
    MoveAnalysisResult analysis, {
    bool deep = false,
    bool revealBest = false,
    CoachLevel? level,
    CoachLang? lang,
  }) async {
    final lv = level ?? _level;
    final lg = lang ?? _lang;
    final reveal = revealBest || deep;

    await CoachSessionStore.instance.load();

    final facts = CoachSessionStore.instance.insights(lg);
    final input = CoachMoveInput.fromResult(analysis);

    final template = CoachTemplateEngine.explainMove(
      input,
      level: lv,
      lang: lg,
      revealBest: reveal,
      personalNote:
          (_isHard(analysis) && facts.isNotEmpty) ? facts.first : null,
    );

    final settings = AppSettings.instance;

    final wantsModel = settings.coachUseModel &&
        (deep || settings.coachExplainAll || _isHard(analysis));

    if (!wantsModel || _busy) return template;

    if (!await ensureLoaded()) return template;

    _busy = true;

    notifyListeners();

    try {
      final raw = await _model.generate(
        system: CoachPromptEngine.system(level: lv, lang: lg),
        user: CoachPromptEngine.move(
          input,
          level: lv,
          lang: lg,
          revealBest: reveal,
          deep: deep,
          playerFacts: facts,
        ),
        maxTokens: deep ? 520 : 380,
        timeout: Duration(seconds: deep ? 70 : 45),
      );

      return CoachPromptEngine.parse(
            raw,
            allowedMoves: input.allowedMoves(revealBest: reveal),
            trustedBetterMove:
                (reveal && input.bestMove.isNotEmpty) ? input.bestMove : null,
          ) ??
          template;
    } catch (_) {
      return template;
    } finally {
      _busy = false;

      _touch();

      notifyListeners();
    }
  }

  Future<CoachExplanation> explainPosition(
    CoachPositionInput analysis, {
    CoachLevel? level,
    CoachLang? lang,
  }) async {
    final lv = level ?? _level;
    final lg = lang ?? _lang;

    final template =
        CoachTemplateEngine.explainPosition(analysis, level: lv, lang: lg);

    if (!AppSettings.instance.coachUseModel || _busy) return template;

    if (!await ensureLoaded()) return template;

    _busy = true;

    notifyListeners();

    try {
      final raw = await _model.generate(
        system: CoachPromptEngine.system(level: lv, lang: lg),
        user: CoachPromptEngine.position(analysis, level: lv, lang: lg),
        maxTokens: 420,
        timeout: const Duration(seconds: 60),
      );

      return CoachPromptEngine.parse(
            raw,
            allowedMoves: analysis.allowedMoves(),
            trustedBetterMove: analysis.bestMove,
          ) ??
          template;
    } catch (_) {
      return template;
    } finally {
      _busy = false;

      _touch();

      notifyListeners();
    }
  }

  Future<CoachExplanation> explainGame(
    List<MoveAnalysisResult> moves, {
    CoachLevel? level,
    CoachLang? lang,
  }) async {
    final lv = level ?? _level;
    final lg = lang ?? _lang;

    await CoachSessionStore.instance.load();

    final facts = CoachSessionStore.instance.insights(lg);
    final inputs = moves.map(CoachMoveInput.fromResult).toList();

    final template = CoachTemplateEngine.explainGame(
      inputs,
      level: lv,
      lang: lg,
      personalNote: facts.isEmpty ? null : facts.first,
    );

    if (!AppSettings.instance.coachUseModel || _busy || moves.isEmpty) {
      return template;
    }

    if (!await ensureLoaded()) return template;

    var loss = 0.0;

    final counts = <String, int>{};

    for (final m in inputs) {
      loss += m.evalLoss;

      final k = m.quality.name;

      counts[k] = (counts[k] ?? 0) + 1;
    }

    final stats = <String, dynamic>{
      'moves': inputs.length,
      'averageCentipawnLoss': (loss * 100 / inputs.length).round(),
      'classifications': counts,
    };

    _busy = true;

    notifyListeners();

    try {
      final raw = await _model.generate(
        system: CoachPromptEngine.system(level: lv, lang: lg),
        user: CoachPromptEngine.game(
          stats,
          level: lv,
          lang: lg,
          playerFacts: facts,
        ),
        maxTokens: 420,
        timeout: const Duration(seconds: 60),
      );

      // لا نقلات مسموحة في ملخص المباراة.
      return CoachPromptEngine.parse(raw, allowedMoves: const <String>{}) ??
          template;
    } catch (_) {
      return template;
    } finally {
      _busy = false;

      _touch();

      notifyListeners();
    }
  }
}

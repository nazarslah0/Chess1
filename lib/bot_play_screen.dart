import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'app_theme.dart';
import 'app_ui.dart';
import 'board_input.dart';
import 'board_widget.dart' show BoardArrow;
import 'bot_setup_view.dart';
import 'engine_service.dart';
import 'game_analysis_screen.dart';
import 'game_review_models.dart';
import 'lichess_data_service.dart';
import 'models.dart';
import 'pv_utils.dart';
import 'sound_service.dart';
import 'training_coach.dart';
import 'training_widgets.dart';
import 'uci_utils.dart';

/// مستوى روبوت: كلها Stockfish بإعدادات قوة مختلفة.
///
/// القيم هنا هي المكان الوحيد لضبط صعوبة الروبوتات:
/// - [options]: خيارات UCI تُرسل للمحرك قبل اللعب.
/// - [depth]: عمق البحث (يُستخدم فقط إن كان [movetimeMs] null).
/// - [movetimeMs]: زمن التفكير لكل نقلة بالميلي ثانية.
/// - [range]: نطاق التقييم المعروض في بطاقة المستوى.
/// التقييمات تقريبية (UCI_Elo معايَر على نمط CCRL).
class BotLevel {
  final String id;
  final String name;
  final String rating;
  final String range;
  final String description;
  final IconData icon;
  final Color color;
  final Map<String, String> options;
  final int depth;
  final int? movetimeMs;

  const BotLevel({
    required this.id,
    required this.name,
    required this.rating,
    required this.range,
    required this.description,
    required this.icon,
    required this.color,
    required this.options,
    this.depth = 12,
    this.movetimeMs,
  });
}

const List<BotLevel> botLevels = <BotLevel>[
  BotLevel(
    id: 'beginner',
    name: 'سهل',
    rating: '~800',
    range: '0 - 800',
    description: 'يرتكب أخطاء كثيرة ويترك قطعه — مناسب للتعلّم',
    icon: Icons.child_care_rounded,
    color: Color(0xFF9AA8C4),
    options: <String, String>{
      'UCI_LimitStrength': 'false',
      'Skill Level': '0',
    },
    depth: 1,
  ),
  BotLevel(
    id: 'novice',
    name: 'مبتدئ',
    rating: '~1000',
    range: '800 - 1200',
    description: 'يلعب أساسيات الشطرنج لكنه يخطئ كثيرًا في التكتيك',
    icon: Icons.emoji_people_rounded,
    color: Color(0xFF2F8BFF),
    options: <String, String>{
      'UCI_LimitStrength': 'false',
      'Skill Level': '4',
    },
    depth: 3,
  ),
  BotLevel(
    id: 'intermediate',
    name: 'متوسط',
    rating: '~1400',
    range: '1200 - 2000',
    description: 'يلعب جيدًا لكنه يخطئ أحيانًا في التكتيك',
    icon: Icons.trending_flat_rounded,
    color: Color(0xFFE0A030),
    options: <String, String>{
      'UCI_LimitStrength': 'true',
      'UCI_Elo': '1400',
    },
    movetimeMs: 150,
  ),
  BotLevel(
    id: 'advanced',
    name: 'متقدم',
    rating: '~2200',
    range: '2000 - 2400',
    description: 'لاعب نادٍ قوي جدًا، أخطاؤه قليلة',
    icon: Icons.trending_up_rounded,
    color: Color(0xFFF08A24),
    options: <String, String>{
      'UCI_LimitStrength': 'true',
      'UCI_Elo': '2200',
    },
    movetimeMs: 300,
  ),
  BotLevel(
    id: 'stockfish',
    name: 'خبير',
    rating: 'أقصى قوة',
    range: '2400+',
    description: 'Stockfish بكامل قوته — لا يكاد يُهزم',
    icon: Icons.memory_rounded,
    color: Color(0xFFEF5350),
    options: <String, String>{
      'UCI_LimitStrength': 'false',
      'Skill Level': '20',
    },
    movetimeMs: 1500,
  ),
];

/// خيارات المحرك أثناء تحليل المدرب: كامل القوة (تُرسَل قبل التحليل
/// وتُستعاد خيارات المستوى قبل نقلة الروبوت).
const Map<String, String> _kAnalysisOptions = <String, String>{
  'UCI_LimitStrength': 'false',
  'Skill Level': '20',
};

/// جلسة تدريب نشطة على نقلة واحدة للمستخدم.
class _Coach {
  final int ply;
  final String fenBefore;
  final String bestUci;
  final String bestSan;
  final String pvSan;
  final MoveJudgement judgement;
  final bool soft;
  final bool reviewOnly;
  final MoveQuality firstQuality;

  /// مستوى التلميح المعروض حاليًا: 1 رسالة، 2 سهم، 3 نقلة + PV.
  int level = 1;

  /// أعلى مستوى طُلب فعلًا عبر محاولات هذه الوضعية (للتسجيل).
  int maxLevel = 1;
  bool bestMoveTried = false;

  /// المستخدم أعاد نقلته (الوضعية عادت لما قبلها).
  bool retrying = false;

  _Coach({
    required this.ply,
    required this.fenBefore,
    required this.bestUci,
    required this.bestSan,
    required this.pvSan,
    required this.judgement,
    required this.soft,
    required this.reviewOnly,
    required this.firstQuality,
  });

  bool get canRetry => !reviewOnly && !retrying;
}

/// آخر نقلة نفّذها المستخدم (لإعادتها «حاول مرة أخرى»).
class _UserMove {
  final int ply;
  final String color;
  final String uci;
  final String san;
  final String fenBefore;
  final String fenAfter;
  final String? lastFromBefore;
  final String? lastToBefore;

  const _UserMove({
    required this.ply,
    required this.color,
    required this.uci,
    required this.san,
    required this.fenBefore,
    required this.fenAfter,
    required this.lastFromBefore,
    required this.lastToBefore,
  });
}

/// العب ضد روبوت: اختيار المستوى واللون والوقت ثم المباراة، مع
/// «التدريب الذكي أثناء المباراة» (مفتاح «تحليل أثناء اللعب»).
class BotPlayScreen extends StatefulWidget {
  const BotPlayScreen({super.key});

  @override
  State<BotPlayScreen> createState() => _BotPlayScreenState();
}

class _BotPlayScreenState extends State<BotPlayScreen> {
  final GameState _state = GameState();
  late final BoardInput _input = BoardInput(_state);
  final SoundService _sound = SoundService();
  final math.Random _rng = math.Random();
  final AppSettings _settings = AppSettings.instance;

  EngineService? _engine;
  TrainingAnalyzer? _analyzer;

  /// خيارات المحرك الحالية: 'bot' (قوة المستوى) أو 'analysis' (كاملة).
  String _engineMode = 'bot';

  BotLevel _level = botLevels[1];
  String _colorChoice = 'w'; // w / b / r
  int _timeSeconds = 60; // ثوانٍ لكل نقلة (0 = بدون وقت)

  bool _started = false;
  bool _starting = false;
  bool _thinking = false;
  String _userColor = 'w';
  String? _result;
  String? _resultText;
  String? _notice;

  // ---- الساعة (وقت التفكير لكل نقلة) ----
  Timer? _clockTimer;
  int? _clockLeft;

  // ---- التدريب الذكي ----
  bool _trainingOn = false;
  bool _analyzing = false;
  _Coach? _coach;
  _UserMove? _lastUser;
  GameState? _variation;
  bool _variationPlayed = false;
  bool _summaryHidden = false;

  final Map<int, TrainingEntry> _entries = <int, TrainingEntry>{};
  final Map<String, PositionEval> _beforeCache = <String, PositionEval>{};

  String? _toastText;
  Color _toastColor = BotPalette.green;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();

    _state.onSound = (kind) => _sound.playKind(kind);
    _state.addListener(_onState);
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _toastTimer?.cancel();

    _analyzer?.cancel(stopEngine: false);

    _disposeVariation();

    _state.removeListener(_onState);
    _engine?.dispose();
    _sound.dispose();
    _state.dispose();
    super.dispose();
  }

  String get _turn {
    final parts = _state.currentFen.split(' ');

    return parts.length > 1 ? parts[1] : 'w';
  }

  // ------------------------------------------------------------
  // المحرك
  // ------------------------------------------------------------

  /// ينشئ المحرك ويضبط قوته حسب المستوى المختار. يعيد false عند الفشل.
  Future<bool> _prepareEngine() async {
    var engine = _engine;

    if (engine == null) {
      engine = EngineService();
      _engine = engine;
      _analyzer = null;
      await engine.init();
    }

    final ok = await engine.setOptions(_level.options);

    if (ok) _engineMode = 'bot';

    return ok;
  }

  /// خيارات قوة المستوى قبل نقلة الروبوت (بعد أي تحليل تدريبي).
  Future<void> _useBotOptions() async {
    final engine = _engine;

    if (engine == null || _engineMode == 'bot') return;

    if (await engine.setOptions(_level.options)) {
      _engineMode = 'bot';
    }
  }

  /// خيارات كاملة القوة لتحليل المدرب.
  Future<bool> _useAnalysisOptions() async {
    final engine = _engine;

    if (engine == null) return false;

    if (_engineMode == 'analysis') return true;

    final ok = await engine.setOptions(_kAnalysisOptions);

    if (ok) _engineMode = 'analysis';

    return ok;
  }

  Future<String?> _engineBestMove(String fen) async {
    final engine = _engine;

    if (engine == null) return null;

    final done = Completer<String?>();

    engine.onBestMove = (m) {
      if (!done.isCompleted) done.complete(m);
    };

    final req = await engine.analyze(
      fen,
      depth: _level.depth,
      multiPv: 1,
      movetimeMs: _level.movetimeMs,
    );

    if (req == null) return null;

    return done.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => null,
    );
  }

  // ------------------------------------------------------------
  // بدء اللعبة
  // ------------------------------------------------------------

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _notice = null;
    });

    final ok = await _prepareEngine();

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _starting = false;
        _notice = 'تعذّر تشغيل Stockfish على هذا الجهاز.';
      });

      return;
    }

    _userColor = _colorChoice == 'r'
        ? (_rng.nextBool() ? 'w' : 'b')
        : _colorChoice;

    _resetTraining();

    _trainingOn = _settings.smartTraining;

    _state.startPosition();
    _state.flipped = _userColor == 'b';
    _input.clear();

    setState(() {
      _started = true;
      _starting = false;
      _result = null;
      _resultText = null;
    });

    _startClock();

    if (_userColor == 'b') {
      await _botMove();
    }
  }

  void _resetTraining() {
    _analyzer?.cancel();

    _closeVariation(notify: false);

    _coach = null;
    _lastUser = null;
    _analyzing = false;
    _summaryHidden = false;
    _toastText = null;
    _toastTimer?.cancel();

    _entries.clear();
    _beforeCache.clear();
  }

  // ------------------------------------------------------------
  // الساعة
  // ------------------------------------------------------------

  void _startClock() {
    _clockTimer?.cancel();

    if (_timeSeconds <= 0) {
      _clockLeft = null;

      return;
    }

    _clockLeft = _timeSeconds;

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(),
    );
  }

  void _resetClock() {
    if (_timeSeconds > 0) _clockLeft = _timeSeconds;
  }

  /// الساعة تعدّ فقط أثناء تفكيرك: تتوقف أثناء تحليل المدرب والتلميحات
  /// والتجربة، وأثناء دور الروبوت.
  void _tick() {
    if (!mounted || !_started || _result != null) return;

    final left = _clockLeft;

    if (left == null) return;

    if (_turn != _userColor ||
        _thinking ||
        _analyzing ||
        _coach != null ||
        _variation != null) {
      return;
    }

    if (left <= 1) {
      _timeout();

      return;
    }

    setState(() => _clockLeft = left - 1);
  }

  void _timeout() {
    final whiteWins = _userColor == 'b';

    _clockTimer?.cancel();

    _closeVariation(notify: false);

    setState(() {
      _clockLeft = 0;
      _coach = null;
      _result = whiteWins ? '1-0' : '0-1';
      _resultText = 'انتهى وقتك — فاز الروبوت (${_level.name})';
    });
  }

  String _clockText(int s) {
    final m = s ~/ 60;
    final r = s % 60;

    return '$m:${r.toString().padLeft(2, '0')}';
  }

  // ------------------------------------------------------------
  // النقلات
  // ------------------------------------------------------------

  Future<String?> _askPromotion() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر قطعة الترقية'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in const <String, String>{
              'q': 'وزير',
              'r': 'رخ',
              'b': 'فيل',
              'n': 'حصان',
            }.entries)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Text(e.value),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(String square) async {
    if (!_started || _thinking || _analyzing || _result != null) return;

    // رقعة التجربة التدريبية للعرض فقط.
    if (_variation != null) return;

    final fenBefore = _state.currentFen;
    final lastFrom = _state.lastFrom;
    final lastTo = _state.lastTo;
    final ply = _state.history.length;

    final moved = await _input.tap(
      square,
      _askPromotion,
      side: _userColor,
    );

    if (!mounted) return;

    setState(() {});

    if (!moved) return;

    if (_checkEnd()) return;

    final um = _UserMove(
      ply: ply,
      color: _userColor,
      uci: _input.lastUci ?? '',
      san: _state.history.isNotEmpty ? _state.history.last.san : '',
      fenBefore: fenBefore,
      fenAfter: _state.currentFen,
      lastFromBefore: lastFrom,
      lastToBefore: lastTo,
    );

    _lastUser = um;

    if (_trainingOn && _settings.trainingAutoAnalysis) {
      final waitForUser = await _runTraining(um);

      if (!mounted) return;

      // ظهرت بطاقة «هناك نقلة أقوى»: الروبوت ينتظر قرارك.
      if (waitForUser) return;
    }

    await _botMove();
  }

  String? _randomLegalUci() {
    final fen = _state.currentFen;
    final board = GameState.parseBoard(fen.split(' ').first);
    final turn = _turn;

    final all = <String>[];

    board.forEach((sq, piece) {
      if (!piece.startsWith(turn)) return;

      for (final t in _state.legalTargets(sq)) {
        final promo = piece.substring(1) == 'P' &&
                (t.endsWith('8') || t.endsWith('1'))
            ? 'q'
            : '';

        all.add('$sq$t$promo');
      }
    });

    return all.isEmpty ? null : all[_rng.nextInt(all.length)];
  }

  bool _applyUci(String uci) {
    final move = parseUci(uci);

    if (move == null) return false;

    return _state.tryMove(
      move.from,
      move.to,
      promotion: move.promotion,
    );
  }

  Future<void> _botMove() async {
    if (!mounted || _result != null) return;

    setState(() => _thinking = true);

    final started = DateTime.now();

    String? uci;

    try {
      await _useBotOptions();

      uci = await _engineBestMove(_state.currentFen);
    } catch (_) {
      uci = null;
    }

    // حدّ أدنى للتفكير حتى لا تُلعب النقلة فورًا (خصوصًا للمبتدئ).
    final elapsed = DateTime.now().difference(started);

    if (elapsed < const Duration(milliseconds: 500)) {
      await Future<void>.delayed(
        const Duration(milliseconds: 500) - elapsed,
      );
    }

    if (!mounted) return;

    // المباراة انتهت أثناء تفكير الروبوت (استسلام / انتهاء الوقت).
    if (_result != null) {
      setState(() => _thinking = false);

      return;
    }

    var ok = uci != null && _applyUci(uci);

    if (!ok) {
      final fallback = _randomLegalUci();

      if (fallback != null) ok = _applyUci(fallback);

      if (mounted) {
        setState(() {
          _notice = 'تعذّر الحصول على نقلة من المحرك؛ لُعبت نقلة عشوائية.';
        });
      }
    }

    if (!mounted) return;

    setState(() => _thinking = false);

    _resetClock();

    _checkEnd();
  }

  // ------------------------------------------------------------
  // التدريب الذكي
  // ------------------------------------------------------------

  String _fenKey(String fen) => fen.trim().split(RegExp(r'\s+')).take(4).join(' ');

  void _cue(String kind) {
    if (_settings.trainingSound) {
      switch (kind) {
        case 'best':
          _sound.playKind('castle');
        case 'hint':
          _sound.playKind('move');
        case 'bad':
          _sound.playKind('game_over');
      }
    }

    if (_settings.trainingHaptic) {
      switch (kind) {
        case 'best':
          HapticFeedback.lightImpact();
        case 'hint':
          HapticFeedback.selectionClick();
        case 'bad':
          HapticFeedback.mediumImpact();
      }
    }
  }

  void _showToast(String text, Color color) {
    _toastTimer?.cancel();

    setState(() {
      _toastText = text;
      _toastColor = color;
    });

    _toastTimer = Timer(
      Duration(seconds: _settings.trainingFeedbackDelaySec),
      () {
        if (mounted) setState(() => _toastText = null);
      },
    );
  }

  /// يحلّل نقلة المستخدم بنسخة Stockfish الموجودة (بلا تجميد للواجهة).
  Future<MoveJudgement?> _judge(_UserMove um) async {
    final engine = _engine;

    if (engine == null || parseUci(um.uci) == null) return null;

    final analyzer = _analyzer ??= TrainingAnalyzer(engine);

    if (!await _useAnalysisOptions()) return null;

    final key = _fenKey(um.fenBefore);

    var before = _beforeCache[key];

    if (before == null) {
      before = await analyzer.analyze(um.fenBefore);

      if (!mounted || before == null) return null;

      _beforeCache[key] = before;
    }

    PositionEval? after;

    if (!isSameUciMove(um.uci, before.bestUci)) {
      after = await analyzer.analyze(um.fenAfter);

      if (!mounted) return null;
    }

    // نهايات اللعب: نتيجة Tablebase (فوز/تعادل/خسارة) أهم من السنتيبون.
    TablebaseDetail? tb;

    if (TablebaseService.isEligible(um.fenBefore)) {
      try {
        tb = await TablebaseService.instance
            .probeDetailed(um.fenBefore)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        tb = null;
      }
    }

    if (!mounted || _result != null) return null;

    return judgeMove(
      fenBefore: um.fenBefore,
      playedUci: um.uci,
      color: um.color,
      ply: um.ply,
      before: before,
      after: after,
      minLossCp: _settings.trainingMinLossCp,
      tbBefore: tb,
    );
  }

  /// تحليل تلقائي بعد نقلتك. يعيد true إذا ظهرت بطاقة المدرب وعلى
  /// الروبوت أن ينتظر قرارك.
  Future<bool> _runTraining(_UserMove um) async {
    setState(() => _analyzing = true);

    final j = await _judge(um);

    if (!mounted) return false;

    setState(() => _analyzing = false);

    if (j == null || _result != null) {
      setState(() => _coach = null);

      return false;
    }

    return _applyJudgement(um, j, reviewOnly: false);
  }

  /// تحليل يدوي لآخر نقلة (عند إيقاف «التحليل التلقائي»).
  Future<void> _manualAnalyze() async {
    final um = _lastUser;

    if (um == null || _analyzing || _thinking || _coach != null) return;

    setState(() => _analyzing = true);

    final j = await _judge(um);

    if (!mounted) return;

    setState(() => _analyzing = false);

    if (j == null) {
      _showToast('تعذّر تحليل النقلة', BotPalette.red);

      return;
    }

    _lastUser = null;

    _applyJudgement(um, j, reviewOnly: true);
  }

  /// يسجّل بيانات النقلة ويعرض ردّ المدرب. true = بطاقة تنتظر المستخدم.
  bool _applyJudgement(
    _UserMove um,
    MoveJudgement j, {
    required bool reviewOnly,
  }) {
    final prev = _coach;

    final carry = (prev != null && prev.fenBefore == um.fenBefore)
        ? prev
        : null;

    final bestOk = parseUci(j.bestUci) != null;

    final stronger = j.hasStrongerMove && bestOk;

    final firstQuality = carry?.firstQuality ?? j.quality;

    final maxLevel = carry?.maxLevel ?? 0;
    final tried = carry?.bestMoveTried ?? false;

    final result = buildTrainingResult(
      ply: um.ply,
      color: um.color,
      san: um.san,
      playedUci: um.uci,
      fenBefore: um.fenBefore,
      fenAfter: um.fenAfter,
      j: j,
      hintShown: maxLevel >= 2,
      hintLevel: maxLevel,
      solutionShown: maxLevel >= 3,
      bestMoveTried: tried,
      trainingCompleted: carry != null && !stronger,
    );

    _entries[um.ply] = TrainingEntry(
      result: result,
      firstQuality: firstQuality,
      coached: carry != null || stronger,
      firstTryBest: carry == null && j.playedWasBest,
    );

    if (!stronger) {
      setState(() => _coach = null);

      if (_settings.trainingFeedback) {
        if (j.kind == CoachKind.best) {
          _cue('best');
          _showToast('🟢 أفضل نقلة!', BotPalette.green);
        } else if (j.kind == CoachKind.excellent) {
          _cue('best');
          _showToast('🟢 ممتاز!', BotPalette.green);
        }
      }

      return false;
    }

    final best = j.bestUci!;

    final bestSan = pvToSan(um.fenBefore, [best]);

    final pv = (j.pv.isNotEmpty && isSameUciMove(j.pv.first, best))
        ? j.pv
        : <String>[best];

    final coach = _Coach(
      ply: um.ply,
      fenBefore: um.fenBefore,
      bestUci: best,
      bestSan: bestSan,
      pvSan: pvToSan(um.fenBefore, pv),
      judgement: j,
      soft: j.kind == CoachKind.soft,
      reviewOnly: reviewOnly,
      firstQuality: firstQuality,
    )
      ..maxLevel = maxLevel < 1 ? 1 : maxLevel
      ..bestMoveTried = tried;

    _closeVariation(notify: false);

    setState(() => _coach = coach);

    if (j.kind == CoachKind.severe) _cue('bad');

    return !reviewOnly;
  }

  void _updateEntry(_Coach c) {
    final e = _entries[c.ply];

    if (e == null) return;

    _entries[c.ply] = e.copyWith(
      result: e.result.copyWith(
        hintShown: c.maxLevel >= 2,
        hintLevel: c.maxLevel,
        solutionShown: c.maxLevel >= 3,
        bestMoveTried: c.bestMoveTried,
      ),
    );
  }

  // ---- التلميحات: 1 رسالة، 2 سهم، 3 النقلة + PV ----

  void _hint() {
    final c = _coach;

    if (c == null || c.level != 1) return;

    final arrow = _settings.trainingHintArrow;
    final solution = _settings.trainingAllowBestMove;

    if (!arrow && !solution) return;

    setState(() {
      c.level = arrow ? 2 : 3;

      if (c.level > c.maxLevel) c.maxLevel = c.level;
    });

    if (arrow && !c.retrying) _openHintView();

    _updateEntry(c);
    _cue('hint');
  }

  void _showSolution() {
    final c = _coach;

    if (c == null || !_settings.trainingAllowBestMove) return;

    setState(() {
      c.level = 3;
      c.maxLevel = 3;
    });

    _updateEntry(c);
    _cue('hint');
  }

  /// يعرض الوضعية قبل نقلتك على رقعة منفصلة (للسهم) دون المساس
  /// بحالة المباراة الأصلية.
  void _openHintView() {
    final c = _coach;

    if (c == null) return;

    final v = _newVariation(c.fenBefore);

    if (v == null) return;

    setState(() {
      _setVariation(v);
      _variationPlayed = false;
    });
  }

  /// Training Variation: يجرّب أفضل نقلة على رقعة منفصلة (GameState
  /// مستقل). المباراة الأصلية لا تتغير أبدًا.
  void _tryBest() {
    final c = _coach;

    if (c == null) return;

    final m = parseUci(c.bestUci);

    if (m == null) return;

    final v = _newVariation(c.fenBefore);

    if (v == null) return;

    if (!v.tryMove(m.from, m.to, promotion: m.promotion)) {
      v.dispose();

      return;
    }

    c.bestMoveTried = true;

    setState(() {
      _setVariation(v);
      _variationPlayed = true;
    });

    _updateEntry(c);
    _cue('best');
  }

  void _closeTrial() {
    final c = _coach;

    _closeVariation();

    if (c != null &&
        !c.retrying &&
        c.level >= 2 &&
        _settings.trainingHintArrow) {
      _openHintView();
    }
  }

  GameState? _newVariation(String fen) {
    final v = GameState();

    if (!v.loadFen(fen)) {
      v.dispose();

      return null;
    }

    v.flipped = _state.flipped;
    v.onSound = (kind) => _sound.playKind(kind);

    return v;
  }

  void _setVariation(GameState? v) {
    _disposeVariation();

    _variation = v;

    v?.addListener(_onState);
  }

  void _disposeVariation() {
    final old = _variation;

    if (old == null) return;

    old.removeListener(_onState);
    old.dispose();

    _variation = null;
  }

  void _closeVariation({bool notify = true}) {
    _variationPlayed = false;

    if (notify && mounted) {
      setState(_disposeVariation);
    } else {
      _disposeVariation();
    }
  }

  /// «حاول مرة أخرى»: تراجع عن نقلتك الأخيرة (قبل أن يردّ الروبوت).
  void _retry() {
    final c = _coach;
    final um = _lastUser;

    if (c == null || um == null || !c.canRetry) return;

    _closeVariation(notify: false);

    final ok = _state.rewindTo(
      um.fenBefore,
      um.ply,
      lastFrom: um.lastFromBefore,
      lastTo: um.lastToBefore,
    );

    if (!ok) {
      setState(() => _notice = 'تعذّرت إعادة النقلة.');

      return;
    }

    _input.clear();

    setState(() {
      c.retrying = true;
      c.level = 1;
    });

    _resetClock();
  }

  /// «متابعة المباراة»: نقلتك تبقى والروبوت يردّ.
  Future<void> _continueGame() async {
    final c = _coach;

    _closeVariation(notify: false);

    setState(() => _coach = null);

    if (c != null && !c.reviewOnly && !_thinking && _result == null) {
      await _botMove();
    }
  }

  // ------------------------------------------------------------
  // نهاية اللعبة
  // ------------------------------------------------------------

  bool _checkEnd() {
    final c = _state.chess;

    String? res;
    String? text;

    try {
      if (c.in_checkmate) {
        final whiteWins = _turn == 'b';

        res = whiteWins ? '1-0' : '0-1';
        text = 'كش مات — فاز ${whiteWins ? 'الأبيض' : 'الأسود'}';
      } else if (c.in_stalemate) {
        res = '1/2-1/2';
        text = 'تعادل (ستاليمايت)';
      } else if (c.in_draw) {
        res = '1/2-1/2';
        text = 'تعادل';
      }
    } catch (_) {}

    if (res == null) return false;

    _closeVariation(notify: false);

    setState(() {
      _coach = null;
      _result = res;
      _resultText = text;
    });

    return true;
  }

  void _resign() {
    final whiteWins = _userColor == 'b';

    _analyzer?.cancel();

    _closeVariation(notify: false);

    setState(() {
      _coach = null;
      _analyzing = false;
      _result = whiteWins ? '1-0' : '0-1';
      _resultText = 'استسلمت — فاز الروبوت (${_level.name})';
    });
  }

  // ------------------------------------------------------------
  // تحليل المباراة
  // ------------------------------------------------------------

  String get _botLabel => 'روبوت ${_level.name}';

  String _buildPgn() {
    final white = _userColor == 'w' ? 'أنت' : _botLabel;
    final black = _userColor == 'w' ? _botLabel : 'أنت';

    final b = StringBuffer()
      ..writeln('[Event "Chess2 vs Bot"]')
      ..writeln('[Site "Chess2"]')
      ..writeln('[White "$white"]')
      ..writeln('[Black "$black"]')
      ..writeln('[Result "${_result ?? '*'}"]')
      ..writeln();

    final moves = StringBuffer();

    for (var i = 0; i < _state.history.length; i++) {
      final m = _state.history[i];

      if (m.color == 'w') {
        moves.write('${(i ~/ 2) + 1}. ${m.san} ');
      } else {
        moves.write(i == 0 ? '1... ${m.san} ' : '${m.san} ');
      }
    }

    b.write('${moves.toString().trim()} ${_result ?? '*'}');

    return b.toString();
  }

  Future<void> _openAnalysis() async {
    if (_state.history.isEmpty) return;

    // شاشة التحليل تشغّل Stockfish الخاص بها، فنُغلق محركنا أولًا
    // ونعيد إنشاءه عند الحاجة بعد العودة.
    final old = _engine;

    _analyzer?.cancel(stopEngine: false);
    _analyzer = null;
    _engine = null;

    await old?.dispose();

    if (!mounted) return;

    final white = _userColor == 'w' ? 'أنت' : _botLabel;
    final black = _userColor == 'w' ? _botLabel : 'أنت';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameAnalysisScreen(
          pgn: _buildPgn(),
          whiteLabel: white,
          blackLabel: black,
          sourceLabel: 'ضد روبوت',
        ),
      ),
    );

    // المحرك سيُنشأ من جديد عند أول نقلة للروبوت (إن لم تنتهِ المباراة).
    if (mounted && _started && _result == null) {
      await _prepareEngine();
    }
  }

  // ------------------------------------------------------------
  // الواجهة
  // ------------------------------------------------------------

  ThemeData _darkTheme() {
    return AppTheme.dark().copyWith(
      scaffoldBackgroundColor: BotPalette.bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        backgroundColor: BotPalette.bg,
        appBar: _started
            ? AppBar(
                backgroundColor: BotPalette.bg,
                foregroundColor: BotPalette.text,
                title: const Text('العب ضد روبوت'),
              )
            : null,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [BotPalette.bgTop, BotPalette.bg],
            ),
          ),
          child: SafeArea(
            // شاشة الإعداد: الصورة تمتد حتى أعلى الشاشة (بدون SafeArea
            // علوي). شاشة المباراة ثابتة (بدون تمرير) حتى لا يتحرك أي
            // شيء عند كل نقلة.
            top: _started,
            child: _started ? _buildGame() : _buildSetup(),
          ),
        ),
      ),
    );
  }

  Widget _buildSetup() {
    return BotSetupView(
      levels: botLevels,
      selectedLevel: _level,
      onLevel: (lv) => setState(() => _level = lv),
      colorChoice: _colorChoice,
      onColor: (c) => setState(() => _colorChoice = c),
      timeSeconds: _timeSeconds,
      onTime: (s) => setState(() => _timeSeconds = s),
      starting: _starting,
      notice: _notice,
      onStart: _start,
      onAdvanced: () => showTrainingAdvancedSheet(context),
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  static const double _barHeight = 44;
  static const double _gap = 6;

  Widget _playerBar(String color) {
    final isUser = color == _userColor;
    final active = _result == null && _turn == color;
    final white = color == 'w';

    Widget trailing = const SizedBox.shrink();

    final left = _clockLeft;

    if (isUser && left != null) {
      trailing = Text(
        _clockText(left),
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: left <= 10 ? BotPalette.red : BotPalette.text,
        ),
      );
    } else if (!isUser && _thinking) {
      trailing = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (active) {
      trailing = const Icon(
        Icons.circle,
        size: 12,
        color: BotPalette.blue,
      );
    }

    return SizedBox(
      height: _barHeight,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: white ? Colors.white : const Color(0xFF222222),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade500),
            ),
            child: Icon(
              isUser ? Icons.person_rounded : _level.icon,
              size: 17,
              color: white ? Colors.black87 : Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUser ? 'أنت' : '$_botLabel (${_level.rating})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: BotPalette.text,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Center(child: trailing),
        ],
      ),
    );
  }

  Widget _statusLine() {
    final myTurn = _result == null && !_thinking && _turn == _userColor;

    String status;

    if (_result != null) {
      status = _resultText ?? 'انتهت المباراة';
    } else if (_analyzing) {
      status = 'جارٍ تحليل النقلة...';
    } else if (_thinking) {
      status = '${_level.name} يفكّر...';
    } else if (_coach != null && !_coach!.retrying) {
      status = 'المدرب ينتظر قرارك';
    } else {
      status = myTurn ? 'دورك' : 'دور الروبوت';
    }

    final showNotice = _notice != null && _result == null;

    return SizedBox(
      height: 28,
      child: Center(
        child: Text(
          showNotice ? _notice! : status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: showNotice ? 12 : 15,
            color: showNotice ? Colors.orange : BotPalette.text,
          ),
        ),
      ),
    );
  }

  Widget _movesStrip() {
    final h = _state.history;

    return SizedBox(
      height: 32,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // reverse: آخر نقلة تبقى ظاهرة دائمًا.
          reverse: true,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < h.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      h[i].color == 'w'
                          ? '${(i ~/ 2) + 1}. ${h[i].san}'
                          : (i == 0
                              ? '${(i ~/ 2) + 1}... ${h[i].san}'
                              : h[i].san),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == h.length - 1
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: i == h.length - 1
                            ? BotPalette.text
                            : BotPalette.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: SizedBox(
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: BotPalette.text),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11,
                    color: BotPalette.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _flip() {
    _state.flipBoard();

    final v = _variation;

    if (v != null && v.flipped != _state.flipped) v.flipBoard();
  }

  /// أزرار ثابتة العدد والمكان: تُعطَّل بدل أن تظهر وتختفي، فلا
  /// يتغير تخطيط الشاشة بين نقلة وأخرى.
  Widget _actionBar() {
    final busy = _thinking || _analyzing;

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _actionButton(
            icon: Icons.flag_outlined,
            label: 'استسلام',
            onTap: (_result != null || _thinking) ? null : _resign,
          ),
          _actionButton(
            icon: Icons.flip_rounded,
            label: 'قلب الرقعة',
            onTap: _flip,
          ),
          _actionButton(
            icon: Icons.query_stats_rounded,
            label: 'تحليل',
            onTap: (busy || _state.history.isEmpty) ? null : _openAnalysis,
          ),
          _actionButton(
            icon: Icons.refresh_rounded,
            label: 'مباراة جديدة',
            onTap: busy
                ? null
                : () {
                    _clockTimer?.cancel();
                    _resetTraining();

                    setState(() {
                      _started = false;
                      _result = null;
                      _resultText = null;
                      _notice = null;
                      _clockLeft = null;
                    });
                  },
          ),
        ],
      ),
    );
  }

  // ---- بطاقة المدرب ----

  List<BoardArrow> _hintArrows() {
    final c = _coach;

    if (c == null || c.level < 2 || !_settings.trainingHintArrow) {
      return const <BoardArrow>[];
    }

    // السهم يخص الوضعية *قبل* نقلتك: يُرسم على رقعة التلميح المنفصلة
    // أو على الرقعة الحقيقية بعد «حاول مرة أخرى».
    final showsBefore =
        c.retrying || (_variation != null && !_variationPlayed);

    if (!showsBefore) return const <BoardArrow>[];

    final m = parseUci(c.bestUci);

    if (m == null) return const <BoardArrow>[];

    return <BoardArrow>[
      BoardArrow(
        from: m.from,
        to: m.to,
        color: BotPalette.gold.withValues(alpha: 0.85),
      ),
    ];
  }

  String _severeBody(_Coach c) {
    final j = c.judgement;

    switch (j.tablebaseVerdict) {
      case 'lostWin':
        return 'هذه النقلة حوّلت وضعية رابحة إلى خاسرة.';
      case 'missedWin':
        return 'هذه النقلة حوّلت الفوز إلى تعادل.';
      case 'blunder':
        return 'هذه النقلة حوّلت التعادل إلى خسارة.';
    }

    return 'هذه النقلة سمحت للخصم بالحصول على أفضلية.\n'
        'هناك نقلة أفضل في هذه الوضعية.';
  }

  Widget? _coachCard() {
    final c = _coach;

    if (c == null) return null;

    final canArrow = _settings.trainingHintArrow;
    final canSolution = _settings.trainingAllowBestMove;

    // تجربة أفضل نقلة على رقعة منفصلة.
    if (_variation != null && _variationPlayed) {
      return CoachCard(
        key: const ValueKey<String>('card-trial'),
        title: '🧪 تجربة تدريبية',
        body: 'هذه تجربة مؤقتة على رقعة منفصلة — لن تتأثر مباراتك.',
        detail: c.bestSan.isEmpty ? null : c.bestSan,
        accent: BotPalette.blue,
        actions: [
          CoachAction('العودة للمباراة', _closeTrial, primary: true),
        ],
      );
    }

    final actions = <CoachAction>[];

    String title;
    String body;
    String? detail;
    Color accent;

    if (c.level <= 1) {
      if (c.retrying) {
        title = '🤔 فكّر في نقلة أقوى';
        body = 'عادت الوضعية إلى ما قبل نقلتك. جرّب نقلة أخرى.';
        accent = BotPalette.blue;
      } else if (c.soft) {
        title = '💡 هناك نقلة أقوى!';
        body = 'نقلتك جيدة، لكن هناك خيار أقوى في هذه الوضعية.\n'
            'ابحث عن نقلة أقوى.';
        accent = BotPalette.gold;
      } else {
        title = '🔴 انتبه!';
        body = '${_severeBody(c)}\nابحث عن نقلة أقوى.';
        accent = BotPalette.red;
      }

      if (c.judgement.onlyMove) {
        body += '\nالوضعية تتطلب نقلة دقيقة (شبه وحيدة).';
      }

      if (c.canRetry) {
        actions.add(
          CoachAction(
            c.soft ? 'حاول العثور عليها' : 'حاول مرة أخرى',
            _retry,
            primary: true,
          ),
        );
      }

      if (canArrow || canSolution) {
        actions.add(CoachAction('إظهار تلميح', _hint));
      }
    } else if (c.level == 2) {
      title = '✨ وجدنا النقلة الأفضل';
      body = 'السهم يوضح النقلة الأقوى.\nهل تريد تجربة هذه النقلة؟';
      accent = BotPalette.gold;

      actions.add(CoachAction('جرّبها', _tryBest, primary: true));

      if (canSolution) actions.add(CoachAction('عرض النقلة', _showSolution));

      if (c.canRetry) actions.add(CoachAction('حاول مرة أخرى', _retry));
    } else {
      title = '✨ أفضل نقلة: ${c.bestSan}';
      body = 'الخط الرئيسي من Stockfish:';
      detail = c.pvSan.isEmpty ? c.bestSan : c.pvSan;
      accent = BotPalette.gold;

      actions.add(CoachAction('جرّبها', _tryBest, primary: true));

      if (c.canRetry) actions.add(CoachAction('حاول مرة أخرى', _retry));
    }

    if (!c.retrying) {
      actions.add(
        CoachAction(
          c.reviewOnly ? 'إغلاق' : 'متابعة المباراة',
          _continueGame,
        ),
      );
    }

    return CoachCard(
      key: ValueKey<String>('card-${c.level}-${c.retrying}-${c.ply}'),
      title: title,
      body: body,
      detail: detail,
      accent: accent,
      actions: actions,
    );
  }

  bool get _canManualAnalyze =>
      _trainingOn &&
      !_settings.trainingAutoAnalysis &&
      _lastUser != null &&
      _coach == null &&
      !_thinking &&
      !_analyzing &&
      _result == null;

  /// الخانة الوحيدة فوق الرقعة (بطاقة المدرب / Feedback / الملخص).
  Widget? _slotWidget() {
    if (_analyzing) {
      return const CoachPill(
        key: ValueKey<String>('analyzing'),
        text: 'جارٍ تحليل النقلة...',
        color: BotPalette.blue,
        spinner: true,
      );
    }

    final card = _coachCard();

    if (card != null) return card;

    if (_result != null && _trainingOn && !_summaryHidden) {
      final summary = TrainingSummary.from(_entries.values);

      if (!summary.isEmpty) {
        return GestureDetector(
          key: const ValueKey<String>('summary'),
          onTap: () => setState(() => _summaryHidden = true),
          child: TrainingSummaryCard(summary: summary),
        );
      }
    }

    final t = _toastText;

    if (t != null) {
      return CoachPill(
        key: ValueKey<String>('toast-$t'),
        text: t,
        color: _toastColor,
      );
    }

    if (_canManualAnalyze) {
      return GestureDetector(
        key: const ValueKey<String>('manual'),
        onTap: _manualAnalyze,
        child: const CoachPill(
          text: '🎓 حلّل نقلتي',
          color: BotPalette.gold,
        ),
      );
    }

    return null;
  }

  Widget _buildGame() {
    final bottomColor = _state.flipped ? 'b' : 'w';
    final topColor = bottomColor == 'w' ? 'b' : 'w';

    final shown = _variation ?? _state;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // الرقعة مربعة وبحجم ثابت يحدده عرض/ارتفاع المساحة؛
                // شريطا اللاعبين فوقها وتحتها بنفس العرض.
                final side = math.max(
                  0.0,
                  math.min(
                    c.maxWidth,
                    c.maxHeight - 2 * (_barHeight + _gap),
                  ),
                );

                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: side,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _playerBar(topColor),
                            const SizedBox(height: _gap),
                            SizedBox(
                              width: side,
                              height: side,
                              child: AppBoard(
                                key: ValueKey<int>(identityHashCode(shown)),
                                state: shown,
                                onTap: _onTap,
                                targets: _variation == null
                                    ? _input.targets
                                    : const <String>{},
                                arrows: _hintArrows(),
                                interactive: _variation == null,
                                maxWidth: null,
                              ),
                            ),
                            const SizedBox(height: _gap),
                            _playerBar(bottomColor),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (c.maxWidth - side) / 2,
                      width: side,
                      bottom: 0,
                      child: FloatingSwitcher(child: _slotWidget()),
                    ),
                  ],
                );
              },
            ),
          ),
          _statusLine(),
          _movesStrip(),
          const SizedBox(height: 4),
          _actionBar(),
        ],
      ),
    );
  }
}

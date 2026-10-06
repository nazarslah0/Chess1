import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analysis_result.dart';
import 'app_settings.dart';
import 'app_ui.dart';
import 'board_widget.dart';
import 'board_input.dart';
import 'engine_service.dart';
import 'game_analysis_screen.dart';
import 'models.dart';
import 'game_review_models.dart';
import 'lichess_data_service.dart';
import 'pv_utils.dart';
import 'sound_service.dart';
import 'settings_screen.dart';
import 'uci_utils.dart';

/// مستوى روبوت: كلها Stockfish بإعدادات قوة مختلفة.
///
/// القيم هنا هي المكان الوحيد لضبط صعوبة الروبوتات:
/// - [options]: خيارات UCI تُرسل للمحرك قبل اللعب.
/// - [depth]: عمق البحث (يُستخدم فقط إن كان [movetimeMs] null).
/// - [movetimeMs]: زمن التفكير لكل نقلة بالميلي ثانية.
/// التقييمات تقريبية (UCI_Elo معايَر على نمط CCRL).
class BotLevel {
  final String id;
  final String name;
  final String rating;
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
    required this.description,
    required this.icon,
    required this.color,
    required this.options,
    this.depth = 12,
    this.movetimeMs,
  });
}

class _LiveTrainingAnalysis {
  final String bestUci;
  final List<String> pv;
  final double evalPawnsWhite;
  final double? secondEvalPawnsWhite;
  final String? secondBestUci;

  const _LiveTrainingAnalysis({
    required this.bestUci,
    required this.pv,
    required this.evalPawnsWhite,
    this.secondEvalPawnsWhite,
    this.secondBestUci,
  });
}

const List<BotLevel> botLevels = <BotLevel>[
  BotLevel(
    id: 'beginner',
    name: 'مبتدئ',
    rating: '~800',
    description: 'يرتكب أخطاء كثيرة ويترك قطعه — مناسب للتعلّم',
    icon: Icons.child_care_rounded,
    color: Color(0xFF7FA650),
    options: <String, String>{
      'UCI_LimitStrength': 'false',
      'Skill Level': '0',
    },
    depth: 1,
  ),
  BotLevel(
    id: 'intermediate',
    name: 'متوسط',
    rating: '~1400',
    description: 'يلعب جيدًا لكنه يخطئ أحيانًا في التكتيك',
    icon: Icons.emoji_people_rounded,
    color: Color(0xFF4F9DDE),
    options: <String, String>{
      'UCI_LimitStrength': 'true',
      'UCI_Elo': '1400',
    },
    movetimeMs: 150,
  ),
  BotLevel(
    id: 'advanced',
    name: 'متقدم',
    rating: '~1900',
    description: 'لاعب نادٍ قوي، أخطاؤه قليلة',
    icon: Icons.trending_up_rounded,
    color: Color(0xFFE0A030),
    options: <String, String>{
      'UCI_LimitStrength': 'true',
      'UCI_Elo': '1900',
    },
    movetimeMs: 300,
  ),
  BotLevel(
    id: 'master',
    name: 'أستاذ',
    rating: '~2500',
    description: 'مستوى أستاذ دولي، نادرًا ما يخطئ',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFD9534F),
    options: <String, String>{
      'UCI_LimitStrength': 'true',
      'UCI_Elo': '2500',
    },
    movetimeMs: 600,
  ),
  BotLevel(
    id: 'stockfish',
    name: 'Stockfish',
    rating: 'أقصى قوة',
    description: 'المحرك بكامل قوته — لا يكاد يُهزم',
    icon: Icons.memory_rounded,
    color: Color(0xFF6A4FC4),
    options: <String, String>{
      'UCI_LimitStrength': 'false',
      'Skill Level': '20',
    },
    movetimeMs: 1500,
  ),
];

/// العب ضد روبوت: اختيار المستوى واللون ثم المباراة.
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

  BotLevel _level = botLevels[0];
  String _colorChoice = 'w'; // w / b / r
  String _timeChoice = '1m';

  bool _started = false;
  bool _starting = false;
  bool _thinking = false;
  String _userColor = 'w';
  String? _result;
  String? _resultText;
  String? _notice;

  bool _trainingAnalyzing = false;
  String? _trainingMessage;
  String? _trainingDetail;
  Color _trainingColor = const Color(0xFF62A8FF);
  String? _trainingHintFrom;
  String? _trainingHintTo;
  String _trainingBestUci = '';
  List<String> _trainingPv = const <String>[];
  String _trainingBeforeFen = '';
  int _trainingEvalBeforeCp = 0;
  int _trainingEvalAfterCp = 0;
  int _trainingLossCp = 0;
  MoveQuality? _trainingQuality;
  bool _trainingHintShown = false;
  int _trainingHintLevel = 0;
  bool _trainingSolutionShown = false;
  bool _trainingBestMoveTried = false;
  int _trainingToken = 0;
  final List<MoveAnalysisResult> _trainingResults = <MoveAnalysisResult>[];

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

  int? get _selectedMoveTimeMs {
    switch (_timeChoice) {
      case '5m':
        return 300000;
      case '3m':
        return 180000;
      case '1m':
        return 60000;
      case '30s':
        return 30000;
      case 'none':
        return null;
    }
    return null;
  }

  /// ينشئ المحرك ويضبط قوته حسب المستوى المختار. يعيد false عند الفشل.
  Future<bool> _prepareEngine() async {
    var engine = _engine;

    if (engine == null) {
      engine = EngineService();
      _engine = engine;
      await engine.init();
    }

    return engine.setOptions(_level.options);
  }

  Future<String?> _engineBestMove(String fen) async {
    final analysis = await _engineAnalyze(fen, multiPv: 1);
    return analysis?.bestUci;
  }

  Future<_LiveTrainingAnalysis?> _engineAnalyze(
    String fen, {
    int multiPv = 2,
  }) async {
    final engine = _engine;
    if (engine == null) return null;

    final done = Completer<_LiveTrainingAnalysis?>();
    PvLine? best;
    PvLine? second;

    engine.onInfoFor = (request, multipv, line) {
      if (multipv == 1) {
        best = line;
      } else if (multipv == 2) {
        second = line;
      }
    };

    engine.onBestMoveFor = (request, uci) {
      if (!done.isCompleted) {
        final b = best;
        done.complete(
          b == null
              ? null
              : _LiveTrainingAnalysis(
                  bestUci: uci.isNotEmpty ? uci : (b.uciMoves.isEmpty ? '' : b.uciMoves.first),
                  pv: b.uciMoves,
                  evalPawnsWhite: b.evalPawns,
                  secondEvalPawnsWhite: second?.evalPawns,
                  secondBestUci: second?.uciMoves.isEmpty == true
                      ? null
                      : second?.uciMoves.first,
                ),
        );
      }
    };

    final req = await engine.analyze(
      fen,
      depth: _level.depth,
      multiPv: multiPv,
      movetimeMs: _selectedMoveTimeMs ?? _level.movetimeMs,
    );

    if (req == null) return null;

    try {
      final budget = (_selectedMoveTimeMs ?? _level.movetimeMs ?? 5000) + 15000;
      return await done.future.timeout(
        Duration(milliseconds: budget.clamp(20000, 330000).toInt()),
        onTimeout: () => null,
      );
    } finally {
      engine.onInfoFor = null;
      engine.onBestMoveFor = null;
    }
  }

  void _clearTrainingOverlay() {
    _trainingMessage = null;
    _trainingDetail = null;
    _trainingHintFrom = null;
    _trainingHintTo = null;
    _trainingBestUci = '';
    _trainingPv = const <String>[];
    _trainingHintShown = false;
    _trainingHintLevel = 0;
    _trainingSolutionShown = false;
    _trainingQuality = null;
  }

  void _trainingFeedbackSound(String kind) {
    if (!_settings.trainingSound) return;
    _sound.playKind(kind);
  }

  void _trainingHaptic() {
    if (_settings.trainingHaptic) {
      HapticFeedback.lightImpact();
    }
  }

  int _cpForMover(double whiteCp, String side) {
    final cp = (whiteCp * 100).round();
    return side == 'w' ? cp : -cp;
  }

  String _phaseForFen(String fen) {
    final board = GameState.parseBoard(fen.split(' ').first);
    final pieces = board.values.length;
    if (pieces <= 10) return 'endgame';
    if (pieces <= 20) return 'middlegame';
    return 'opening';
  }

  MoveQuality _trainingClassification(int lossCp) {
    if (lossCp <= 0) return MoveQuality.best;
    if (lossCp < 20) return MoveQuality.excellent;
    if (lossCp < 50) return MoveQuality.good;
    if (lossCp < 100) return MoveQuality.inaccuracy;
    if (lossCp < 200) return MoveQuality.mistake;
    return MoveQuality.blunder;
  }

  Future<void> _analyzeUserMove(String fenBefore, String playedUci) async {
    if (!_settings.smartTraining || !_settings.autoAnalysis) return;

    final token = ++_trainingToken;
    setState(() {
      _trainingAnalyzing = true;
      _trainingMessage = 'جارٍ تحليل النقلة...';
      _trainingDetail = null;
      _trainingHintFrom = null;
      _trainingHintTo = null;
    });

    final fenAfter = _state.currentFen;
    final before = await _engineAnalyze(fenBefore, multiPv: 2);
    if (!mounted || token != _trainingToken) return;
    final after = await _engineAnalyze(fenAfter, multiPv: 1);
    if (!mounted || token != _trainingToken) return;

    if (before == null || after == null || before.bestUci.isEmpty) {
      setState(() => _trainingAnalyzing = false);
      return;
    }

    final side = fenBefore.split(' ').length > 1 ? fenBefore.split(' ')[1] : 'w';
    var bestUci = before.bestUci;
    var pv = before.pv;
    var tbForcedQuality = false;
    MoveQuality? tbQuality;

    // إن كانت الوضعية ضمن Tablebase الموجودة في المشروع، تكون النتيجة
    // المضمونة أعلى أولوية من فروقات Stockfish الصغيرة.
    try {
      if (TablebaseService.isEligible(fenBefore) && TablebaseService.isEligible(fenAfter)) {
        final tbBefore = await TablebaseService.instance.probeDetailed(fenBefore);
        final tbAfter = await TablebaseService.instance.probeDetailed(fenAfter);
        if (!mounted || token != _trainingToken) return;

        if (tbBefore != null && tbAfter != null && tbBefore.result != null && tbAfter.result != null) {
          final moverBefore = tbBefore.result!;
          final moverAfter = -tbAfter.result!;
          final winningCandidates = tbBefore.moves.where((m) => m.result == moverBefore).toList();
          if (winningCandidates.isNotEmpty) {
            bestUci = winningCandidates.first.uci;
            pv = [bestUci];
          }
          if (moverAfter < moverBefore) {
            tbForcedQuality = true;
            tbQuality = moverAfter == -1 ? MoveQuality.blunder : MoveQuality.miss;
          }
        }
      }
    } catch (_) {
      // يبقى تحليل Stockfish هو البديل الآمن إذا تعذر Tablebase.
    }
    final beforeCp = _cpForMover(before.evalPawnsWhite, side);
    final afterCp = _cpForMover(after.evalPawnsWhite, side);
    final loss = math.max(0, beforeCp - afterCp);
    final same = isSameUciMove(playedUci, bestUci);
    final effectiveLoss = same ? 0 : loss;
    final quality = tbForcedQuality && tbQuality != null
        ? tbQuality
        : _trainingClassification(effectiveLoss);
    final threshold = _settings.minEvalLossCp;

    _trainingResults.add(
      MoveAnalysisResult(
        ply: _state.history.length,
        moveNumber: (_state.history.length + 1) ~/ 2,
        side: side,
        san: _state.history.isNotEmpty ? _state.history.last.san : '',
        uci: playedUci,
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        evaluationBeforeCp: beforeCp,
        evaluationAfterCp: afterCp,
        evaluationLossCp: effectiveLoss,
        evaluationBeforeWhiteCp: (before.evalPawnsWhite * 100).round(),
        evaluationAfterWhiteCp: (after.evalPawnsWhite * 100).round(),
        bestMoveSan: _bestMoveSan(fenBefore, bestUci),
        bestMoveUci: bestUci,
        principalVariationUci: pv,
        classification: quality,
        phase: _phaseForFen(fenBefore),
        materialBefore: 0,
        materialAfter: 0,
        isCritical: quality == MoveQuality.mistake || quality == MoveQuality.blunder || quality == MoveQuality.miss,
        isBestMove: same,
        isBrilliant: quality == MoveQuality.brilliant,
        isMistake: quality == MoveQuality.mistake,
        isBlunder: quality == MoveQuality.blunder,
        isMissedOpportunity: quality == MoveQuality.miss,
        isGreat: quality == MoveQuality.great,
        playedMove: playedUci,
        hintShown: false,
        hintLevel: 0,
        solutionShown: false,
        bestMoveTried: false,
        trainingCompleted: same || effectiveLoss < threshold,
      ),
    );
    unawaited(_persistTrainingResults());

    setState(() {
      _trainingAnalyzing = false;
      _trainingBestUci = bestUci;
      _trainingPv = pv;
      _trainingBeforeFen = fenBefore;
      _trainingEvalBeforeCp = beforeCp;
      _trainingEvalAfterCp = afterCp;
      _trainingLossCp = effectiveLoss;
      _trainingQuality = quality;
    });

    if (same || effectiveLoss < threshold) {
      if (_settings.trainingFeedback && mounted) {
        setState(() {
          _trainingMessage = same ? '🟢 أفضل نقلة!' : '🟢 ممتاز!';
          _trainingDetail = same ? null : 'نقلتك ضمن أفضل الخيارات في هذه الوضعية.';
          _trainingColor = const Color(0xFF62D394);
        });
        _trainingFeedbackSound('move');
        _trainingHaptic();
        Future<void>.delayed(
          Duration(milliseconds: _settings.feedbackDelayMs),
          () {
            if (mounted && token == _trainingToken) {
              setState(_clearTrainingOverlay);
              _botMove();
            }
          },
        );
      } else {
        await _botMove();
      }
      return;
    }

    if (!mounted) return;

    final serious = quality == MoveQuality.mistake || quality == MoveQuality.blunder || quality == MoveQuality.miss;
    setState(() {
      _trainingMessage = serious ? '🔴 انتبه!' : '💡 هناك نقلة أقوى!';
      _trainingDetail = serious
          ? 'هذه النقلة سمحت للخصم بالحصول على أفضلية. هناك نقلة أفضل في هذه الوضعية.'
          : 'نقلتك جيدة، لكن هناك خيار أقوى. حاول العثور عليه قبل مشاهدة الحل.';
      _trainingColor = serious ? const Color(0xFFFF5D6C) : const Color(0xFFFFC857);
    });
    _trainingFeedbackSound(serious ? 'check' : 'move');
    _trainingHaptic();
  }

  Future<void> _persistTrainingResults() async {
    if (_trainingResults.isEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        'chess2_training_session_last',
        jsonEncode(_trainingResults.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  void _updateLastTraining({
    bool? hintShown,
    int? hintLevel,
    bool? solutionShown,
    bool? bestMoveTried,
    bool? trainingCompleted,
  }) {
    if (_trainingResults.isEmpty) return;
    final i = _trainingResults.length - 1;
    _trainingResults[i] = _trainingResults[i].copyWith(
      hintShown: hintShown,
      hintLevel: hintLevel,
      solutionShown: solutionShown,
      bestMoveTried: bestMoveTried,
      trainingCompleted: trainingCompleted,
    );
    unawaited(_persistTrainingResults());
  }

  Future<void> _showTrainingHint() async {
    if (_trainingBestUci.isEmpty) return;
    final parsed = parseUci(_trainingBestUci);
    if (parsed == null) return;

    _updateLastTraining(hintShown: true, hintLevel: 2);
    setState(() {
      _trainingHintShown = true;
      _trainingHintLevel = 2;
      _trainingHintFrom = parsed.from;
      _trainingHintTo = parsed.to;
      _trainingMessage = '💡 تلميح';
      _trainingDetail = 'السهم يوضح اتجاه أفضل نقلة دون كشفها كنص.';
      _trainingColor = const Color(0xFF62A8FF);
    });
    _trainingFeedbackSound('move');
    _trainingHaptic();
  }

  Future<void> _showTrainingSolution() async {
    if (_trainingBestUci.isEmpty) return;
    final parsed = parseUci(_trainingBestUci);
    if (parsed == null) return;
    final san = _bestMoveSan(_trainingBeforeFen, _trainingBestUci);

    _updateLastTraining(hintShown: true, hintLevel: 3, solutionShown: true);
    setState(() {
      _trainingSolutionShown = true;
      _trainingHintShown = true;
      _trainingHintLevel = 3;
      _trainingHintFrom = parsed.from;
      _trainingHintTo = parsed.to;
      _trainingMessage = '✨ أفضل نقلة';
      final pvText = pvToSan(_trainingBeforeFen, _trainingPv);
      _trainingDetail = san.isEmpty
          ? (_trainingBestUci.toUpperCase() + (pvText.isEmpty ? '' : ' • $pvText'))
          : '$san — ${_trainingBestUci.toUpperCase()}${pvText.isEmpty ? '' : '\n$pvText'}';
      _trainingColor = const Color(0xFF62A8FF);
    });
  }

  String _bestMoveSan(String fen, String uci) {
    final parsed = parseUci(uci);
    if (parsed == null) return '';
    final temp = GameState();
    try {
      temp.loadFen(fen);
      final before = temp.history.length;
      if (!temp.tryMove(parsed.from, parsed.to, promotion: parsed.promotion)) {
        return '';
      }
      return temp.history.length > before ? temp.history.last.san : '';
    } finally {
      temp.dispose();
    }
  }

  Future<void> _openTrainingVariation() async {
    if (_trainingBeforeFen.isEmpty || _trainingBestUci.isEmpty) return;
    _trainingBestMoveTried = false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrainingVariationSheet(
        fen: _trainingBeforeFen,
        bestUci: _trainingBestUci,
        flipped: _state.flipped,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _updateLastTraining(bestMoveTried: true, trainingCompleted: true);
      setState(() {
        _trainingBestMoveTried = true;
        _trainingMessage = '✨ أحسنت! جربت النقلة الأفضل.';
        _trainingDetail = 'هذه تجربة تدريبية فقط؛ المباراة الأصلية لم تتغير.';
        _trainingColor = const Color(0xFF62D394);
      });
    }
  }

  void _continueAfterTraining() {
    _updateLastTraining(trainingCompleted: true);
    _trainingToken++;
    if (!mounted) return;
    setState(_clearTrainingOverlay);
    _botMove();
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

    _state.startPosition();
    _state.flipped = _userColor == 'b';
    _input.clear();

    setState(() {
      _started = true;
      _starting = false;
      _result = null;
      _resultText = null;
      _clearTrainingOverlay();
      _trainingToken++;
      _trainingResults.clear();
    });

    if (_userColor == 'b') {
      await _botMove();
    }
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
    if (!_started || _thinking || _trainingAnalyzing || _result != null) return;

    // عند وجود Feedback تدريبي، تسمح أزرار الـoverlay بإكمال الدور.
    if (_trainingMessage != null && _trainingBestUci.isNotEmpty) return;

    final beforeFen = _state.currentFen;
    final moved = await _input.tap(
      square,
      _askPromotion,
      side: _userColor,
    );

    if (!mounted) return;
    setState(() {});
    if (!moved) return;

    final playedUci = _input.lastUci ?? '';
    _input.lastUci = null;

    if (_checkEnd()) return;

    if (_settings.smartTraining && _settings.autoAnalysis && playedUci.isNotEmpty) {
      await _analyzeUserMove(beforeFen, playedUci);
      return;
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
    _trainingToken++;
    if (_trainingMessage != null) {
      setState(_clearTrainingOverlay);
    }

    setState(() => _thinking = true);

    final started = DateTime.now();

    String? uci;

    try {
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

    _checkEnd();
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

    setState(() {
      _result = res;
      _resultText = text;
    });

    return true;
  }

  void _resign() {
    final whiteWins = _userColor == 'b';

    setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _started ? AppBar(title: const Text('العب ضد روبوت')) : null,
      body: SafeArea(
        // شاشة المباراة ثابتة (بدون تمرير) حتى لا يتحرك أي شيء عند كل
        // نقلة؛ شاشة الإعداد وحدها قابلة للتمرير.
        child: _started
            ? _buildGame()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildSetup(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSetup() {
    final dark = const Color(0xFF071321);
    final panel = const Color(0xFF0D1B2A);
    final blue = const Color(0xFF2F8BFF);
    final gold = const Color(0xFFFFB52E);

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: dark,
      ),
      child: Container(
        color: dark,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF17283C),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '🤖 العب ضد روبوت',
                            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'اختر المستوى والإعدادات وابدأ اللعبة',
                            style: TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _setupHero(),
              const SizedBox(height: 12),
              _setupPanel(
                panel,
                title: 'مستوى الصعوبة',
                subtitle: 'اختر قوة خصمك',
                icon: Icons.bar_chart_rounded,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final lv in botLevels)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _difficultyTile(lv, blue),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _setupPanel(
                panel,
                title: 'اللعب بالقطع',
                subtitle: 'اختر لون قطعك',
                icon: Icons.person_rounded,
                child: Row(
                  children: [
                    _colorTile('r', 'عشوائي', Icons.casino_rounded),
                    const SizedBox(width: 8),
                    _colorTile('w', 'أبيض', Icons.circle, light: true),
                    const SizedBox(width: 8),
                    _colorTile('b', 'أسود', Icons.circle),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _setupPanel(
                panel,
                title: 'وقت التفكير',
                subtitle: 'الوقت لكل نقلة',
                icon: Icons.access_time_rounded,
                child: Row(
                  children: [
                    for (final item in const [
                      ('5m', '5 دقائق'),
                      ('3m', '3 دقائق'),
                      ('1m', '1 دقيقة'),
                      ('30s', '30 ث'),
                      ('none', 'بدون وقت'),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _choiceButton(
                            item.$1,
                            item.$2,
                            _timeChoice == item.$1,
                            () => setState(() => _timeChoice = item.$1),
                            icon: item.$1 == 'none'
                                ? Icons.all_inclusive_rounded
                                : Icons.schedule_rounded,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _setupPanel(
                panel,
                title: 'شكل الرقعة',
                subtitle: 'اختر شكل رقعة الشطرنج',
                icon: Icons.palette_rounded,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < AppSettings.allBoardThemes.length && i < 6; i++)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _boardThemeTile(i),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 86,
                    child: _setupSmallButton(
                      Icons.settings_rounded,
                      'إعدادات\nمتقدمة',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 72,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _starting ? null : _start,
                        icon: _starting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.play_arrow_rounded, size: 30),
                        label: Text(
                          _starting ? 'جارٍ تشغيل المحرك...' : 'ابدأ اللعبة',
                          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 86,
                    child: _setupSmallButton(
                      Icons.school_rounded,
                      'التدريب\nالذكي',
                      () async {
                        await _settings.setSmartTraining(!_settings.smartTraining);
                        if (mounted) setState(() {});
                      },
                      active: _settings.smartTraining,
                    ),
                  ),
                ],
              ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_notice!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _setupHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 7.2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/bot/bot_hero.png', fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Colors.black.withValues(alpha: .72), Colors.transparent, Colors.black.withValues(alpha: .12)],
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 18,
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0A1422),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x5567B0FF)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('محرك قوي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          SizedBox(width: 7),
                          Icon(Icons.psychology_rounded, color: Color(0xFF62A8FF)),
                        ],
                      ),
                      SizedBox(height: 3),
                      Text('Stockfish', style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 5),
                      Text('أداء احترافي وتحليل دقيق', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _setupPanel(Color color, {required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x332C6BAA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF62A8FF), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _difficultyTile(BotLevel lv, Color blue) {
    final selected = lv.id == _level.id;
    return GestureDetector(
      onTap: () => setState(() => _level = lv),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 112,
        height: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? blue.withValues(alpha: .20) : const Color(0xFF13243A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? blue : const Color(0x332D4C6B), width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: blue.withValues(alpha: .22), blurRadius: 14)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(lv.icon, color: selected ? blue : Colors.white70, size: 25),
            const SizedBox(height: 4),
            Text(lv.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(lv.rating, style: TextStyle(color: selected ? blue : Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _colorTile(String id, String label, IconData icon, {bool light = false}) {
    final selected = _colorChoice == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _colorChoice = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 62,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0C63D9) : const Color(0xFF13243A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? const Color(0xFF58A6FF) : const Color(0x332D4C6B), width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: light ? Colors.white : Colors.white70, size: 18),
              const SizedBox(width: 7),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choiceButton(String id, String label, bool selected, VoidCallback onTap, {required IconData icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 64,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D6BEA) : const Color(0xFF13243A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF58A6FF) : const Color(0x332D4C6B)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.white60),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _boardThemeTile(int index) {
    final theme = AppSettings.allBoardThemes[index];
    final selected = _settings.boardThemeIndex == index;
    return GestureDetector(
      onTap: () => _settings.setBoardTheme(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 92,
        height: 86,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF13243A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFF58A6FF) : const Color(0x332D4C6B), width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GridView.count(
                  crossAxisCount: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < 16; i++)
                      Container(color: ((i ~/ 4 + i) & 1) == 0 ? theme.light : theme.dark),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(theme.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _setupSmallButton(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: active ? const Color(0xFF123C6E) : const Color(0xFF13243A),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide(color: active ? const Color(0xFF4B9CFF) : const Color(0x332D4C6B)),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF62A8FF)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static const double _barHeight = 44;
  static const double _gap = 6;

  Widget _playerBar(String color) {
    final isUser = color == _userColor;
    final active = _result == null && _turn == color;
    final white = color == 'w';

    Widget trailing = const SizedBox.shrink();

    if (!isUser && _thinking) {
      trailing = const CircularProgressIndicator(strokeWidth: 2);
    } else if (active) {
      trailing = Icon(
        Icons.circle,
        size: 12,
        color: Theme.of(context).colorScheme.primary,
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
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 18,
            height: 18,
            child: Center(child: trailing),
          ),
        ],
      ),
    );
  }

  Widget _statusLine() {
    final myTurn = _result == null && !_thinking && _turn == _userColor;

    final status = _result != null
        ? (_resultText ?? 'انتهت المباراة')
        : (_thinking
            ? '${_level.name} يفكّر...'
            : (myTurn ? 'دورك' : 'دور الروبوت'));

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
            color: showNotice ? Colors.orange : null,
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
                            ? null
                            : Colors.grey.shade600,
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
                Icon(icon, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trainingSummary() {
    final completed = _trainingResults.where((r) => r.isBestMove).length;
    final hinted = _trainingResults.where((r) => r.hintShown).length;
    final solutions = _trainingResults.where((r) => r.solutionShown).length;
    final errors = _trainingResults.where((r) => r.isMistake || r.isBlunder || r.isMissedOpportunity).length;
    final pct = _trainingResults.isEmpty ? 0 : (completed * 100 / _trainingResults.length).round();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334B9CFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF62A8FF), size: 20),
          const SizedBox(width: 7),
          Expanded(child: Text('أداء التدريب: وجدت $pct% من النقلات القوية بنفسك', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          Text('تلميح $hinted  •  حل $solutions  •  أخطاء $errors', style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _trainingOverlay() {
    final color = _trainingColor;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey('${_trainingMessage ?? ''}|${_trainingHintLevel}|$_trainingAnalyzing'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: const Color(0xF20B1726),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .55)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: .10), blurRadius: 18)],
        ),
        child: _trainingAnalyzing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 9),
                  Text('جارٍ تحليل النقلة...', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_rounded, color: color, size: 21),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _trainingMessage ?? '',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  if (_trainingDetail != null) ...[
                    const SizedBox(height: 4),
                    Text(_trainingDetail!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                  if (_trainingBestUci.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (!_trainingHintShown && _settings.showHintArrow)
                          OutlinedButton.icon(
                            onPressed: _showTrainingHint,
                            icon: const Icon(Icons.lightbulb_outline_rounded, size: 17),
                            label: const Text('إظهار تلميح'),
                          ),
                        if (!_trainingSolutionShown)
                          OutlinedButton(
                            onPressed: _showTrainingSolution,
                            child: const Text('عرض النقلة'),
                          ),
                        if (_settings.allowBestMove)
                          FilledButton.icon(
                            onPressed: _openTrainingVariation,
                            icon: const Icon(Icons.play_arrow_rounded, size: 17),
                            label: const Text('جرّبها'),
                          ),
                        OutlinedButton(
                          onPressed: _continueAfterTraining,
                          child: const Text('متابعة المباراة'),
                        ),
                      ],
                    ),
                    if (_trainingHintLevel == 2 && !_trainingSolutionShown)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TextButton(
                          onPressed: _showTrainingSolution,
                          child: const Text('المستوى 3: عرض الحل والخط الرئيسي'),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  /// أزرار ثابتة العدد والمكان: تُعطَّل بدل أن تظهر وتختفي، فلا
  /// يتغير تخطيط الشاشة بين نقلة وأخرى.
  Widget _actionBar() {
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
            onTap: _state.flipBoard,
          ),
          _actionButton(
            icon: Icons.query_stats_rounded,
            label: 'تحليل',
            onTap: (_thinking || _state.history.isEmpty)
                ? null
                : _openAnalysis,
          ),
          _actionButton(
            icon: Icons.refresh_rounded,
            label: 'مباراة جديدة',
            onTap: _thinking
                ? null
                : () => setState(() {
                      _started = false;
                      _result = null;
                      _resultText = null;
                      _notice = null;
                      _trainingResults.clear();
                      _trainingToken++;
                      _clearTrainingOverlay();
                    }),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final bottomColor = _state.flipped ? 'b' : 'w';
    final topColor = bottomColor == 'w' ? 'b' : 'w';

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

                return Center(
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
                            state: _state,
                            onTap: _onTap,
                            targets: _input.targets,
                            arrows: (_trainingHintFrom != null && _trainingHintTo != null)
                                ? [
                                    BoardArrow(
                                      from: _trainingHintFrom!,
                                      to: _trainingHintTo!,
                                      color: const Color(0xFF62A8FF),
                                    ),
                                  ]
                                : const [],
                            maxWidth: null,
                          ),
                        ),
                        if (_trainingMessage != null || _trainingAnalyzing)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _trainingOverlay(),
                          ),
                        const SizedBox(height: _gap),
                        _playerBar(bottomColor),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _statusLine(),
          if (_result != null && _trainingResults.isNotEmpty) _trainingSummary(),
          _movesStrip(),
          const SizedBox(height: 4),
          _actionBar(),
        ],
      ),
    );
  }
}

class _BotCard extends StatelessWidget {
  final BotLevel level;
  final bool selected;
  final VoidCallback onTap;

  const _BotCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: level.color.withValues(alpha: selected ? 0.18 : 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? level.color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: level.color.withValues(alpha: 0.25),
                child: Icon(level.icon, color: level.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          level.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          level.rating,
                          style: TextStyle(
                            fontSize: 12,
                            color: level.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: level.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingVariationSheet extends StatefulWidget {
  final String fen;
  final String bestUci;
  final bool flipped;

  const _TrainingVariationSheet({
    required this.fen,
    required this.bestUci,
    required this.flipped,
  });

  @override
  State<_TrainingVariationSheet> createState() => _TrainingVariationSheetState();
}

class _TrainingVariationSheetState extends State<_TrainingVariationSheet> {
  late final GameState _trial;
  late final BoardInput _input;
  String? _message;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _trial = GameState();
    _trial.loadFen(widget.fen);
    _trial.flipped = widget.flipped;
    _input = BoardInput(_trial);
  }

  @override
  void dispose() {
    _trial.dispose();
    super.dispose();
  }

  Future<String?> _promotion() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر قطعة الترقية'),
        content: Wrap(
          spacing: 8,
          children: [
            for (final e in const <String, String>{
              'q': 'وزير',
              'r': 'رخ',
              'b': 'فيل',
              'n': 'حصان',
            }.entries)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Text(e.value),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _tap(String square) async {
    if (_done) return;
    final moved = await _input.tap(square, _promotion);
    if (!mounted) return;
    if (!moved) {
      setState(() {});
      return;
    }

    final played = _input.lastUci ?? '';
    _input.lastUci = null;
    final correct = isSameUciMove(played, widget.bestUci);

    setState(() {
      _done = true;
      _message = correct
          ? '✨ ممتاز! هذه هي النقلة الأفضل.'
          : 'حاولت النقلة، لكن هذه ليست أفضل نقلة.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseUci(widget.bestUci);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1726),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x335CAEFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),
            const Text('🎓 تجربة تدريبية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            const Text(
              'جرّب العثور على أفضل نقلة. هذه الوضعية منفصلة عن المباراة الأصلية.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
              child: AspectRatio(
                aspectRatio: 1,
                child: AppBoard(
                  state: _trial,
                  onTap: _tap,
                  targets: _input.targets,
                  arrows: _done && parsed != null
                      ? [BoardArrow(from: parsed.from, to: parsed.to, color: const Color(0xFF62A8FF))]
                      : const [],
                  maxWidth: null,
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(_message!, style: TextStyle(color: _message!.startsWith('✨') ? const Color(0xFF62D394) : const Color(0xFFFFC857), fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _done),
                child: Text(_done ? 'العودة إلى المباراة' : 'متابعة المباراة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

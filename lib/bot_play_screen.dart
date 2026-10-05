import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'board_input.dart';
import 'board_widget.dart';
import 'engine_service.dart';
import 'game_analysis_screen.dart';
import 'models.dart';
import 'sound_service.dart';
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

  EngineService? _engine;

  BotLevel _level = botLevels[1];
  String _colorChoice = 'w'; // w / b / r

  bool _started = false;
  bool _starting = false;
  bool _thinking = false;
  String _userColor = 'w';
  String? _result;
  String? _resultText;
  String? _notice;

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

    _state.startPosition();
    _state.flipped = _userColor == 'b';
    _input.clear();

    setState(() {
      _started = true;
      _starting = false;
      _result = null;
      _resultText = null;
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
    if (!_started || _thinking || _result != null) return;

    final moved = await _input.tap(
      square,
      _askPromotion,
      side: _userColor,
    );

    if (!mounted) return;

    setState(() {});

    if (!moved) return;

    if (_checkEnd()) return;

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
      appBar: AppBar(title: const Text('العب ضد روبوت')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (!_started) _buildSetup() else _buildGame(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetup() {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر الروبوت',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          for (final lv in botLevels) ...[
            _BotCard(
              level: lv,
              selected: lv.id == _level.id,
              onTap: () => setState(() => _level = lv),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          const Text(
            'ألعب بالقطع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('الأبيض'),
                selected: _colorChoice == 'w',
                onSelected: (_) => setState(() => _colorChoice = 'w'),
              ),
              ChoiceChip(
                label: const Text('الأسود'),
                selected: _colorChoice == 'b',
                onSelected: (_) => setState(() => _colorChoice = 'b'),
              ),
              ChoiceChip(
                label: const Text('عشوائي'),
                selected: _colorChoice == 'r',
                onSelected: (_) => setState(() => _colorChoice = 'r'),
              ),
            ],
          ),
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(_notice!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _starting ? null : _start,
              icon: _starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_starting ? 'جارٍ تشغيل المحرك...' : 'ابدأ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final myTurn = _result == null && !_thinking && _turn == _userColor;

    final status = _result != null
        ? (_resultText ?? 'انتهت المباراة')
        : (_thinking
            ? '${_level.name} يفكّر...'
            : (myTurn ? 'دورك' : 'دور الروبوت'));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '${_level.name} (${_level.rating})',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) => BoardWidget(
              state: _state,
              boardTheme: AppSettings.instance.boardTheme,
              pieceTheme: AppSettings.instance.pieceTheme,
              onTap: _onTap,
              targets: _input.targets,
            ),
          ),
        ),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(
            _notice!,
            style: const TextStyle(color: Colors.orange, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (_result == null)
              OutlinedButton(
                onPressed: _thinking ? null : _resign,
                child: const Text('استسلام'),
              ),
            OutlinedButton(
              onPressed: _state.flipBoard,
              child: const Text('قلب الرقعة'),
            ),
            if (_state.history.isNotEmpty)
              FilledButton.icon(
                onPressed: _thinking ? null : _openAnalysis,
                icon: const Icon(Icons.query_stats_rounded),
                label: const Text('تحليل المباراة'),
              ),
            FilledButton.tonal(
              onPressed: _thinking
                  ? null
                  : () => setState(() {
                        _started = false;
                        _result = null;
                        _resultText = null;
                        _notice = null;
                      }),
              child: const Text('مباراة جديدة'),
            ),
          ],
        ),
      ],
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

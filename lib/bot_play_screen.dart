import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads_service.dart';
import 'app_top_bar.dart';
import 'app_ui.dart';
import 'board_input.dart';
import 'brand.dart';
import 'engine_service.dart';
import 'game_analysis_screen.dart';
import 'l10n.dart';
import 'models.dart';
import 'sound_service.dart';
import 'uci_utils.dart';

/// مستوى روبوت: كلها Stockfish بإعدادات قوة مختلفة.
///
/// [BotLevel.fromElo] هو المكان الوحيد الذي يحوّل التقييم (100–3200)
/// إلى إعدادات المحرك:
/// - تحت 1320: Stockfish لا يدعم UCI_Elo أقل من ذلك، فنخفّض Skill Level
///   وعمق البحث، ونُدخل احتمال نقلة عشوائية للمستويات الأضعف.
/// - من 1320 إلى 3189: UCI_LimitStrength مع UCI_Elo.
/// - 3190 فما فوق: كامل القوة.
/// التقييمات تقريبية.
class BotLevel {
  final String id;
  final String name;
  final int elo;
  final String description;
  final String? asset;
  final Map<String, String> options;
  final int depth;
  final int? movetimeMs;

  /// احتمال أن يلعب الروبوت نقلة قانونية عشوائية بدل نقلة المحرك.
  final double randomMoveChance;

  const BotLevel({
    required this.id,
    required this.name,
    required this.elo,
    required this.description,
    required this.options,
    this.asset,
    this.depth = 12,
    this.movetimeMs,
    this.randomMoveChance = 0,
  });

  factory BotLevel.fromElo({
    required String id,
    required String name,
    required int elo,
    String description = '',
    String? asset,
  }) {
    final e = elo.clamp(100, 3200).toInt();

    if (e < 1320) {
      final skill = e < 1000 ? 0 : (e < 1150 ? 2 : 4);
      final depth = e < 900 ? 1 : (e < 1100 ? 2 : (e < 1250 ? 3 : 4));

      return BotLevel(
        id: id,
        name: name,
        elo: e,
        description: description,
        asset: asset,
        options: <String, String>{
          'UCI_LimitStrength': 'false',
          'Skill Level': '$skill',
        },
        depth: depth,
        randomMoveChance: e < 1000 ? (1000 - e) / 1000 * 0.5 : 0,
      );
    }

    if (e >= 3190) {
      return BotLevel(
        id: id,
        name: name,
        elo: e,
        description: description,
        asset: asset,
        options: const <String, String>{
          'UCI_LimitStrength': 'false',
          'Skill Level': '20',
        },
        movetimeMs: 1500,
      );
    }

    return BotLevel(
      id: id,
      name: name,
      elo: e,
      description: description,
      asset: asset,
      options: <String, String>{
        'UCI_LimitStrength': 'true',
        'UCI_Elo': '$e',
      },
      movetimeMs: 100 + ((e - 1320) * 900 / 1870).round(),
    );
  }

  String get rating => '~$elo';
}

/// حدود شريط «المستوى المخصص» (الحد الأقصى = أعلى UCI_Elo في Stockfish).
const int kBotCustomMin = 1100;
const int kBotCustomMax = 3190;

/// ستة مستويات موزّعة بالتساوي من 850 إلى 3200.
final List<BotLevel> botLevels = <BotLevel>[
  BotLevel.fromElo(
    id: 'beginner',
    name: 'المبتدئ',
    elo: 850,
    description: 'يصلح للمبتدئين لتعلم الأساسيات',
    asset: 'assets/bots/bot_1.webp',
  ),
  BotLevel.fromElo(
    id: 'intermediate',
    name: 'المتوسط',
    elo: 1320,
    description: 'خصم متوازن',
    asset: 'assets/bots/bot_3.webp',
  ),
  BotLevel.fromElo(
    id: 'advanced',
    name: 'المتقدم',
    elo: 1790,
    description: 'يلعب بخطط جيدة',
    asset: 'assets/bots/bot_4.webp',
  ),
  BotLevel.fromElo(
    id: 'expert',
    name: 'الخبير',
    elo: 2260,
    description: 'خصم قوي ويفكر بعمق',
    asset: 'assets/bots/bot_5.webp',
  ),
  BotLevel.fromElo(
    id: 'master',
    name: 'الأستاذ',
    elo: 2730,
    description: 'أسلوب متوازن وعالي الدقة',
    asset: 'assets/bots/bot_6.webp',
  ),
  BotLevel.fromElo(
    id: 'international',
    name: 'الأستاذ الدولي',
    elo: 3200,
    description: 'أعلى مستوى صعوبة',
    asset: 'assets/bots/bot_7.webp',
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
  late final BoardInput _input = BoardInput(_state)
    ..onIllegal = () => _sound.playIllegal();
  final SoundService _sound = SoundService();
  final math.Random _rng = math.Random();

  EngineService? _engine;

  BotLevel _level = botLevels[0];
  double _customElo = 1500;
  final TextEditingController _eloCtrl = TextEditingController(text: '1500');
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
    _eloCtrl.dispose();
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
        _notice = tr('تعذّر تشغيل Stockfish على هذا الجهاز.');
      });

      return;
    }

    _userColor = _colorChoice == 'r'
        ? (_rng.nextBool() ? 'w' : 'b')
        : _colorChoice;

    _state.startPosition();
    _state.flipped = _userColor == 'b';
    _input.clear();
    _sound.playGameStart();

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
        title: const TrText('اختر قطعة الترقية'),
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
                child: Text(tr(e.value)),
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

    if (_level.randomMoveChance > 0 &&
        _rng.nextDouble() < _level.randomMoveChance) {
      // المستويات الضعيفة جدًا: نقلة عشوائية أحيانًا.
      uci = _randomLegalUci();
    } else {
      try {
        uci = await _engineBestMove(_state.currentFen);
      } catch (_) {
        uci = null;
      }
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
          _notice = tr('تعذّر الحصول على نقلة من المحرك؛ لُعبت نقلة عشوائية.');
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

  /// إعلان بيني بعد انتهاء المباراة (بعد لحظة ليرى المستخدم النتيجة).
  Future<void> _adAfterGame() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    await AdsService.instance.showInterstitial();
  }

  bool _checkEnd() {
    final c = _state.chess;

    String? res;
    String? text;

    try {
      if (c.in_checkmate) {
        final whiteWins = _turn == 'b';

        res = whiteWins ? '1-0' : '0-1';
        text = tr('كش مات — فاز {v}', {'v': whiteWins ? tr('الأبيض') : tr('الأسود')});
      } else if (c.in_stalemate) {
        res = '1/2-1/2';
        text = tr('تعادل (ستاليمايت)');
      } else if (c.in_draw) {
        res = '1/2-1/2';
        text = tr('تعادل');
      }
    } catch (_) {}

    if (res == null) return false;

    setState(() {
      _result = res;
      _resultText = text;
    });

    unawaited(_adAfterGame());

    return true;
  }

  void _resign() {
    final whiteWins = _userColor == 'b';

    setState(() {
      _result = whiteWins ? '1-0' : '0-1';
      _resultText = tr('استسلمت — فاز الروبوت ({name})', {'name': tr(_level.name)});
    });

    _sound.playGameOver();

    unawaited(_adAfterGame());
  }

  // ------------------------------------------------------------
  // تحليل المباراة
  // ------------------------------------------------------------

  String get _botLabel => tr('روبوت {name}', {'name': tr(_level.name)});

  String _buildPgn() {
    final white = _userColor == 'w' ? tr('أنت') : _botLabel;
    final black = _userColor == 'w' ? _botLabel : tr('أنت');

    final b = StringBuffer()
      ..writeln('[Event "Golden Chess vs Bot"]')
      ..writeln('[Site "Golden Chess"]')
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

    final white = _userColor == 'w' ? tr('أنت') : _botLabel;
    final black = _userColor == 'w' ? _botLabel : tr('أنت');

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameAnalysisScreen(
          pgn: _buildPgn(),
          whiteLabel: white,
          blackLabel: black,
          sourceLabel: tr('ضد روبوت'),
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
      backgroundColor: _started ? null : _kSetupBg,
      appBar: const AppTopBar(title: 'العب ضد روبوت'),
      body: SafeArea(
        // شاشة المباراة ثابتة (بدون تمرير) حتى لا يتحرك أي شيء عند كل
        // نقلة؛ شاشة الإعداد وحدها قابلة للتمرير.
        child: _started
            ? _buildGame()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                child: Center(child: _buildSetup()),
              ),
      ),
    );
  }

  /// يختار المستوى ثم يبدأ المباراة فورًا.
  void _play(BotLevel lv) {
    if (_starting) return;

    setState(() => _level = lv);

    _start();
  }

  BotLevel _customLevel() => BotLevel.fromElo(
        id: 'custom',
        name: 'مستوى مخصص',
        elo: _customElo.round(),
      );

  void _onCustomSlide(double v) {
    setState(() {
      _customElo = v;
      _eloCtrl.text = v.round().toString();
      _level = _customLevel();
    });
  }

  void _onCustomTyped(String s) {
    final v = int.tryParse(s);

    if (v == null || v < kBotCustomMin || v > kBotCustomMax) return;

    setState(() {
      _customElo = v.toDouble();
      _level = _customLevel();
    });
  }

  void _playCustom() {
    final v = (int.tryParse(_eloCtrl.text) ?? _customElo.round())
        .clamp(kBotCustomMin, kBotCustomMax)
        .toInt();

    _customElo = v.toDouble();
    _eloCtrl.text = '$v';

    _play(_customLevel());
  }

  Widget _colorPicker() {
    Widget chip(String key, String label, IconData icon) {
      final sel = _colorChoice == key;

      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _colorChoice = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: sel
                  ? GoldColors.main.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: sel ? GoldColors.main : Colors.white12,
                width: sel ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: sel ? GoldColors.main : Colors.white60,
                ),
                const SizedBox(width: 6),
                Text(
                  tr(label),
                  style: TextStyle(
                    color: sel ? GoldColors.main : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrText(
          'ألعب بالقطع',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            chip('w', 'الأبيض', Icons.circle_outlined),
            const SizedBox(width: 8),
            chip('b', 'الأسود', Icons.circle),
            const SizedBox(width: 8),
            chip('r', 'عشوائي', Icons.shuffle_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildSetup() {
    Localizations.localeOf(context);

    Widget card(BotLevel lv) => _BotGridCard(
          level: lv,
          selected: _level.id == lv.id,
          onSelect: () => setState(() => _level = lv),
          onPlay: _starting ? null : () => _play(lv),
        );

    final rows = <Widget>[];

    for (var i = 0; i < botLevels.length; i += 2) {
      rows
        ..add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(botLevels[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < botLevels.length
                      ? card(botLevels[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        )
        ..add(const SizedBox(height: 12));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _colorPicker(),
          const SizedBox(height: 16),
          ...rows,
          _CustomLevelCard(
            selected: _level.id == 'custom',
            elo: _customElo,
            controller: _eloCtrl,
            onSelect: () => setState(() => _level = _customLevel()),
            onSlide: _onCustomSlide,
            onTyped: _onCustomTyped,
            onPlay: _starting ? null : _playCustom,
          ),
          if (_starting) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: GoldColors.main,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  tr('جارٍ تشغيل المحرك...'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            Text(
              _notice!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFF8A80)),
            ),
          ],
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
              isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
              size: 17,
              color: white ? Colors.black87 : Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUser ? tr('أنت') : '$_botLabel (${tr(_level.rating)})',
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
        ? (_resultText ?? tr('انتهت المباراة'))
        : (_thinking
            ? tr('{name} يفكّر...', {'name': tr(_level.name)})
            : (myTurn ? tr('دورك') : tr('دور الروبوت')));

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

  /// أزرار ثابتة العدد والمكان: تُعطَّل بدل أن تظهر وتختفي، فلا
  /// يتغير تخطيط الشاشة بين نقلة وأخرى.
  Widget _actionBar() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _actionButton(
            icon: Icons.flag_outlined,
            label: tr('استسلام'),
            onTap: (_result != null || _thinking) ? null : _resign,
          ),
          _actionButton(
            icon: Icons.flip_rounded,
            label: tr('قلب الرقعة'),
            onTap: _state.flipBoard,
          ),
          _actionButton(
            icon: Icons.query_stats_rounded,
            label: tr('تحليل'),
            onTap: (_thinking || _state.history.isEmpty)
                ? null
                : _openAnalysis,
          ),
          _actionButton(
            icon: Icons.refresh_rounded,
            label: tr('مباراة جديدة'),
            onTap: _thinking
                ? null
                : () => setState(() {
                      _started = false;
                      _result = null;
                      _resultText = null;
                      _notice = null;
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
                            maxWidth: null,
                          ),
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
          _movesStrip(),
          const SizedBox(height: 4),
          _actionBar(),
        ],
      ),
    );
  }
}

const Color _kSetupBg = Color(0xFF0A0C12);
const Color _kCardBg = Color(0xFF12151C);
const Color _kOnGold = Color(0xFF2A1D00);

BoxDecoration _cardDecoration({required bool selected}) => BoxDecoration(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: selected ? GoldColors.main : Colors.white10,
        width: selected ? 1.6 : 1,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: GoldColors.main.withValues(alpha: 0.28),
                blurRadius: 16,
              ),
            ]
          : null,
    );

/// زر «العب» الذهبي.
class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;

  const _GoldButton({
    required this.label,
    required this.onTap,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: kGoldGradient,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: _kOnGold,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// بطاقة روبوت: صورة، الاسم والتقييم، وصف، وزر لعب.
class _BotGridCard extends StatelessWidget {
  final BotLevel level;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onPlay;

  const _BotGridCard({
    required this.level,
    required this.selected,
    required this.onSelect,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final asset = level.asset;

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        clipBehavior: Clip.antiAlias,
        decoration: _cardDecoration(selected: selected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.25,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (asset != null)
                    Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.45),
                      cacheWidth: 520,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), _kCardBg],
                        stops: [0.55, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            tr(level.name),
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${level.elo}',
                        style: const TextStyle(
                          color: GoldColors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: Text(
                      tr(level.description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _GoldButton(label: tr('العب'), onTap: onPlay),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «مستوى مخصص»: منزلق تقييم من 100 إلى 3200 مع حقل رقمي وزر لعب.
class _CustomLevelCard extends StatelessWidget {
  final bool selected;
  final double elo;
  final TextEditingController controller;
  final VoidCallback onSelect;
  final ValueChanged<double> onSlide;
  final ValueChanged<String> onTyped;
  final VoidCallback? onPlay;

  const _CustomLevelCard({
    required this.selected,
    required this.elo,
    required this.controller,
    required this.onSelect,
    required this.onSlide,
    required this.onTyped,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final gold = GoldColors.main;

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: _cardDecoration(selected: selected),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TrText(
                        'مستوى مخصص',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('اختر تقييم ربوت من {min} إلى {max}', {
                          'min': kBotCustomMin,
                          'max': kBotCustomMax,
                        }),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: gold,
                inactiveTrackColor: Colors.white12,
                thumbColor: GoldColors.light,
                overlayColor: gold.withValues(alpha: 0.15),
                trackHeight: 4,
                tickMarkShape: SliderTickMarkShape.noTickMark,
              ),
              child: Slider(
                min: kBotCustomMin.toDouble(),
                max: kBotCustomMax.toDouble(),
                divisions: (kBotCustomMax - kBotCustomMin) ~/ 10,
                value: elo
                    .clamp(kBotCustomMin, kBotCustomMax)
                    .toDouble(),
                onChanged: onSlide,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    cursorColor: gold,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: gold.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: gold, width: 1.4),
                      ),
                    ),
                    onChanged: onTyped,
                    onTap: onSelect,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GoldButton(
                    label: tr('العب'),
                    onTap: onPlay,
                    height: 46,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

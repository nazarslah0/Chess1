import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'board_input.dart';
import 'board_options.dart';
import 'board_widget.dart' show BoardLabel;
import 'lichess_puzzles.dart';
import 'models.dart';
import 'sound_service.dart';
import 'uci_utils.dart';

/// شاشة ألغاز Lichess (متعددة الخطوات) — تُستخدم لثلاث صفحات بحسب
/// [category]: "ألغاز بريليانت" و"ألغاز جيك ميت" و"ألغاز" (تدريب
/// بلا حدود على كل الألغاز).
///
/// آلية اللغز (صيغة Lichess):
///  1. تُلعب نقلة الخصم الأولى تلقائيًا.
///  2. اللاعب يجد النقلة الصحيحة، ثم يردّ الخصم تلقائيًا، وهكذا حتى
///     نهاية الخط.
///  3. في ألغاز الكش مات (وفي كل لغز ينتهي بكش مات داخل صفحة
///     "ألغاز") تُقبل أي نقلة تُنهي المباراة بكش مات حتى لو كانت غير
///     النقلة المسجّلة (كما يفعل Lichess).
class LichessPuzzlesScreen extends StatefulWidget {
  final PuzzleCategory category;

  const LichessPuzzlesScreen({super.key, required this.category});

  @override
  State<LichessPuzzlesScreen> createState() => _LichessPuzzlesScreenState();
}

class _LichessPuzzlesScreenState extends State<LichessPuzzlesScreen> {
  final GameState _state = GameState();
  late final BoardInput _input = BoardInput(_state);
  final SoundService _sound = SoundService();

  List<LichessPuzzle> _items = <LichessPuzzle>[];
  Set<String> _solved = <String>{};
  int _index = 0;

  /// مستويات الصعوبة: كل مستوى شريحة من الألغاز مرتبة بالتقييم.
  List<List<LichessPuzzle>> _levels = <List<LichessPuzzle>>[];
  List<String> _ranges = <String>[];
  int _level = 0;
  bool _loading = true;

  /// رقم النقلة التالية المطلوبة من اللاعب داخل moves.
  int _ply = 0;

  /// true أثناء تشغيل نقلة الخصم/إعادة الوضعية: نتجاهل اللمسات.
  bool _busy = false;

  bool _finished = false;
  bool _revealed = false;

  /// يزيد مع كل تحميل لغز لإلغاء أي تأخير متأخر من لغز سابق.
  int _gen = 0;

  /// لا صوت أثناء إعادة بناء الوضعية.
  bool _silent = false;

  String? _feedback;
  Color _feedbackColor = AppColors.muted;
  String? _hintUci;
  String? _solutionText;

  /// مربع تظهر فوقه علامة Brilliant بعد أول نقلة صحيحة.
  String? _brilliantSquare;

  /// هل يُحلّ هذا اللغز كلغز كش مات (تُقبل أي نقلة تُنهي بكش مات)؟
  bool _mateMode(LichessPuzzle p) =>
      widget.category == PuzzleCategory.mate ||
      (widget.category == PuzzleCategory.training && p.isMate);

  /// هل تظهر علامة Brilliant بعد أول نقلة صحيحة؟
  bool _brilliantMode(LichessPuzzle p) =>
      widget.category == PuzzleCategory.brilliant ||
      (widget.category == PuzzleCategory.training && p.isBrilliant);

  Color get _accent {
    switch (widget.category) {
      case PuzzleCategory.mate:
        return const Color(0xFFE5534B);
      case PuzzleCategory.brilliant:
        return const Color(0xFF2EC4C4);
      case PuzzleCategory.training:
        return const Color(0xFF4F8DF7);
    }
  }

  @override
  void initState() {
    super.initState();

    _state.onSound = (kind) {
      if (!_silent) _sound.playKind(kind);
    };
    _state.addListener(_onState);

    _load();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gen++;
    _state.removeListener(_onState);
    _sound.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await LichessPuzzleRepository.loadCategory(widget.category);
    final solved = await LichessPuzzleRepository.loadSolved(widget.category);

    if (!mounted) return;

    final built = _buildLevels(all);

    // نبدأ من أول مستوى فيه ألغاز لم تُحلّ بعد.
    var level = 0;

    while (level < built.levels.length - 1 &&
        _doneIn(built.levels[level], solved) >= built.levels[level].length) {
      level++;
    }

    final items = built.levels[level];

    // ثم من أول لغز غير محلول داخله.
    var start = items.indexWhere((p) => !solved.contains(p.id));

    if (start < 0) start = 0;

    setState(() {
      _levels = built.levels;
      _ranges = built.ranges;
      _level = level;
      _items = items;
      _solved = solved;
      _index = start;
      _loading = false;
    });

    unawaited(_loadCurrent());
  }

  /// يقسم الألغاز إلى مستويات حسب تقييم اللغز الحقيقي (حدود ثابتة)،
  /// فمستوى "مبتدئ" ألغازه سهلة فعلًا وهكذا. أي مستوى فيه أقل من
  /// [_kNeedPerLevel] لغزًا يُدمج مع المستوى الذي قبله (أو بعده إن كان
  /// الأول)، حتى لا يوجد مستوى لا يمكن إكمال شرطه.
  ({List<List<LichessPuzzle>> levels, List<String> ranges}) _buildLevels(
    List<LichessPuzzle> all,
  ) {
    final sorted = List<LichessPuzzle>.of(all)
      ..sort((a, b) => a.rating.compareTo(b.rating));

    var groups = <List<LichessPuzzle>>[
      for (var i = 0; i < _kBandStarts.length; i++)
        sorted
            .where(
              (p) =>
                  p.rating >= _kBandStarts[i] &&
                  (i == _kBandStarts.length - 1 ||
                      p.rating < _kBandStarts[i + 1]),
            )
            .toList(),
    ];

    // ندمج المستويات الصغيرة.
    var merged = true;

    while (merged && groups.length > 1) {
      merged = false;

      for (var i = 0; i < groups.length; i++) {
        if (groups[i].length >= _kNeedPerLevel) continue;

        final target = i == 0 ? 1 : i - 1;
        final combined = <LichessPuzzle>[...groups[target], ...groups[i]]
          ..sort((a, b) => a.rating.compareTo(b.rating));

        final next = <List<LichessPuzzle>>[];

        for (var j = 0; j < groups.length; j++) {
          if (j == i) continue;

          next.add(j == target ? combined : groups[j]);
        }

        groups = next;
        merged = true;

        break;
      }
    }

    final ranges = <String>[
      for (final g in groups)
        g.isEmpty ? '' : '${g.first.rating}–${g.last.rating}',
    ];

    return (levels: groups, ranges: ranges);
  }

  static int _doneIn(List<LichessPuzzle> l, Set<String> solved) =>
      l.where((p) => solved.contains(p.id)).length;

  static int _needFor(List<LichessPuzzle> l) =>
      l.length < _kNeedPerLevel ? l.length : _kNeedPerLevel;

  bool _unlocked(int i) =>
      i == 0 ||
      (i < _levels.length &&
          _doneIn(_levels[i - 1], _solved) >= _needFor(_levels[i - 1]));

  List<_LevelInfo> _infos() => <_LevelInfo>[
        for (var i = 0; i < _levels.length; i++)
          _LevelInfo(
            name: _kLevelNames[i],
            range: _ranges[i],
            done: _doneIn(_levels[i], _solved),
            need: _needFor(_levels[i]),
            unlocked: _unlocked(i),
          ),
      ];

  void _selectLevel(int i) {
    if (i == _level || i < 0 || i >= _levels.length) return;

    if (!_unlocked(i)) {
      showAppSnack(
        context,
        'أنهِ ${_needFor(_levels[i - 1])} ألغاز من مستوى '
        '${_kLevelNames[i - 1]} لفتح هذا المستوى',
      );

      return;
    }

    final items = _levels[i];

    var start = items.indexWhere((p) => !_solved.contains(p.id));

    if (start < 0) start = 0;

    setState(() {
      _level = i;
      _items = items;
      _index = start;
    });

    unawaited(_loadCurrent());
  }

  void _openLevelsSheet() {
    final infos = _infos();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12151F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'مسار المستويات',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'أنهِ $_kNeedPerLevel ألغاز في كل مستوى لفتح الذي يليه',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: infos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LevelRow(
                    index: i,
                    info: infos[i],
                    current: i == _level,
                    accent: _accent,
                    previousName: i > 0 ? _kLevelNames[i - 1] : '',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _selectLevel(i);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ThemeData _screenTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: _accent,
      scaffoldBackgroundColor: const Color(0xFF0E1118),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0E1118),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
    );
  }

  LichessPuzzle? get _current =>
      _items.isEmpty ? null : _items[_index.clamp(0, _items.length - 1)];

  // ------------------------------------------------------------
  // أدوات الرقعة
  // ------------------------------------------------------------

  bool _applyUci(String uci) {
    final m = parseUci(uci);

    if (m == null) return false;

    return _state.tryMove(m.from, m.to, promotion: m.promotion);
  }

  /// يعيد الوضعية الأصلية ثم يلعب أول [upTo] نقلة من اللغز بصمت.
  void _rebuild(LichessPuzzle p, int upTo) {
    _silent = true;

    try {
      _state.loadFen(p.fen);

      for (var i = 0; i < upTo && i < p.moves.length; i++) {
        if (!_applyUci(p.moves[i])) break;
      }
    } finally {
      _silent = false;
    }

    _state.flipped = p.solverSide == 'b';
    _input.clear();
  }

  bool _isCheckmate() {
    try {
      return _state.chess.in_checkmate;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _askPromotion() {
    const options = <MapEntry<String, String>>[
      MapEntry('q', 'وزير'),
      MapEntry('r', 'رخ'),
      MapEntry('b', 'فيل'),
      MapEntry('n', 'حصان'),
    ];

    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('الترقية إلى'),
        children: [
          for (final o in options)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(o.key),
              child: Text(o.value),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // تحميل اللغز
  // ------------------------------------------------------------

  Future<void> _loadCurrent() async {
    final p = _current;

    if (p == null) return;

    final gen = ++_gen;

    setState(() {
      _busy = true;
      _finished = false;
      _revealed = false;
      _ply = 0;
      _feedback = null;
      _hintUci = null;
      _solutionText = null;
      _brilliantSquare = null;
    });

    _rebuild(p, 0);

    // لحظة قصيرة ليرى اللاعب الوضعية قبل نقلة الخصم.
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (!mounted || gen != _gen) return;

    _applyUci(p.moves[0]);

    setState(() {
      _ply = 1;
      _busy = false;
    });
  }

  void _go(int delta) {
    if (_items.isEmpty) return;

    setState(() {
      _index = (_index + delta) % _items.length;

      if (_index < 0) _index += _items.length;
    });

    unawaited(_loadCurrent());
  }

  void _goNextUnsolved() {
    if (_items.isEmpty) return;

    for (var step = 1; step <= _items.length; step++) {
      final i = (_index + step) % _items.length;

      if (!_solved.contains(_items[i].id)) {
        setState(() => _index = i);
        unawaited(_loadCurrent());

        return;
      }
    }

    // كل ألغاز المستوى محلولة: ننتقل تلقائيًا إلى التالي إن وُجد.
    if (_level < _levels.length - 1 && _unlocked(_level + 1)) {
      _selectLevel(_level + 1);

      return;
    }

    _go(1);
  }

  // ------------------------------------------------------------
  // اللعب
  // ------------------------------------------------------------

  Future<void> _onTap(String square) async {
    final p = _current;

    if (p == null || _busy || _finished || _ply >= p.moves.length) return;

    final gen = _gen;

    final moved = await _input.tap(
      square,
      _askPromotion,
      side: p.solverSide,
    );

    if (!mounted || gen != _gen) return;

    setState(() {});

    if (!moved) return;

    final uci = _input.lastUci ?? '';

    final matchesLine = isSameUciMove(p.moves[_ply], uci);

    // Lichess: في ألغاز الكش مات تُقبل أي نقلة تُنهي المباراة بكش مات.
    final acceptsAsMate = _mateMode(p) && _isCheckmate();

    if (matchesLine || acceptsAsMate) {
      // أول نقلة صحيحة في ألغاز بريليانت: نظهر علامة Brilliant فوق القطعة.
      if (_ply == 1 && _brilliantMode(p)) {
        _brilliantSquare = parseUci(uci)?.to;
      } else {
        _brilliantSquare = null;
      }

      _ply++;

      if (acceptsAsMate || _ply >= p.moves.length) {
        await _onSolved(p);

        return;
      }

      setState(() {
        _hintUci = null;
        _busy = true;
        _feedback = 'صحيح ✅ تابع';
        _feedbackColor = AppColors.success;
      });

      await Future<void>.delayed(const Duration(milliseconds: 450));

      if (!mounted || gen != _gen) return;

      // رد الخصم التلقائي.
      _applyUci(p.moves[_ply]);

      setState(() {
        _ply++;
        _busy = false;
      });

      return;
    }

    // نقلة خاطئة: نُظهر الرسالة ثم نعيد الوضعية قبل النقلة الخاطئة.
    setState(() {
      _busy = true;
      _feedback = 'ليست النقلة الصحيحة — حاول مرة أخرى';
      _feedbackColor = AppColors.error;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted || gen != _gen) return;

    _rebuild(p, _ply);

    setState(() {
      _busy = false;
      _brilliantSquare = null;
    });
  }

  Future<void> _onSolved(LichessPuzzle p) async {
    // لا نحتسب اللغز محلولًا إن كُشف الحل.
    final counted = !_revealed;

    final before = _doneIn(_items, _solved);
    final need = _needFor(_items);

    var message =
        _mateMode(p) ? 'كش مات! أحسنت ✅' : 'أحسنت! حللت اللغز ✅';

    if (counted && !_solved.contains(p.id)) {
      final after = before + 1;

      if (before < need && after >= need) {
        message = _level < _levels.length - 1
            ? 'أحسنت! فتحت مستوى ${_kLevelNames[_level + 1]} 🎉'
            : 'أكملت المسار كله! 👑';
      }
    }

    setState(() {
      _finished = true;
      _busy = false;
      _hintUci = null;
      _feedback = message;
      _feedbackColor = AppColors.success;

      if (counted) _solved = <String>{..._solved, p.id};
    });

    if (counted) await LichessPuzzleRepository.markSolved(widget.category, p.id);

    // انتهى آخر لغز في المستوى: ننتقل تلقائيًا إلى المستوى التالي.
    if (counted &&
        mounted &&
        _level < _levels.length - 1 &&
        _doneIn(_items, _solved) >= _items.length) {
      final gen = _gen;

      setState(() {
        _feedback = 'أنهيت مستوى ${_kLevelNames[_level]} 🎉 '
            'ننتقل إلى ${_kLevelNames[_level + 1]}…';
      });

      await Future<void>.delayed(const Duration(milliseconds: 1600));

      if (!mounted || gen != _gen) return;

      _selectLevel(_level + 1);
    }
  }

  void _hint() {
    final p = _current;

    if (p == null || _busy || _finished || _ply >= p.moves.length) return;

    setState(() => _hintUci = p.moves[_ply]);
  }

  void _reveal() {
    final p = _current;

    if (p == null || _busy || _finished || _ply >= p.moves.length) return;

    final line = _sanLine(_state.currentFen, p.moves.sublist(_ply));

    setState(() {
      _revealed = true;
      _hintUci = p.moves[_ply];
      _solutionText = line;
    });
  }

  /// يحوّل خطًّا بصيغة UCI إلى SAN انطلاقًا من [fen] (للعرض فقط).
  static String _sanLine(String fen, List<String> uciMoves) {
    final c = ch.Chess();

    try {
      if (c.load(fen) == false) return '';
    } catch (_) {
      return '';
    }

    final out = <String>[];

    for (final u in uciMoves) {
      final m = parseUci(u);

      if (m == null) break;

      final args = <String, dynamic>{'from': m.from, 'to': m.to};

      if (m.promotion != null) args['promotion'] = m.promotion;

      try {
        if (c.move(args) == false) break;
      } catch (_) {
        break;
      }

      final h = c.getHistory();

      if (h.isNotEmpty) out.add('${h.last}');
    }

    return out.join(' ');
  }

  // ------------------------------------------------------------
  // الواجهة
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = _current;

    return Theme(
      data: _screenTheme(),
      child: Scaffold(
        body: SafeArea(
          child: _loading
              ? _withBack(const LoadingView())
              : (p == null ? _withBack(_buildEmpty()) : _buildPuzzle(p)),
        ),
      ),
    );
  }

  /// زر رجوع فوق حالتي التحميل/الفراغ (لا يوجد شريط علوي في الصفحة).
  Widget _withBack(Widget child) => Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IconButton(
              tooltip: 'رجوع',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(child: child),
        ],
      );

  Widget _buildEmpty() => const CenteredMessage('تعذّر تحميل الألغاز.');

  Widget _buildPuzzle(LichessPuzzle p) {
    final sideName = p.solverSide == 'w' ? 'الأبيض' : 'الأسود';

    final String goal;

    if (_mateMode(p)) {
      goal = 'أنهِ المباراة بكش مات';
    } else if (_brilliantMode(p)) {
      goal = 'اعثر على النقلة البريليانت';
    } else {
      goal = 'اعثر على أفضل نقلة';
    }

    final arrow = parseUci(_hintUci);

    final line = _solutionText;

    return PuzzleLayout(
      title: 'الدور على $sideName — $goal',
      header: _LevelHeader(
        category: widget.category,
        accent: _accent,
        level: _level,
        infos: _infos(),
        onOpenSheet: _openLevelsSheet,
      ),
      board: AppBoard(
        state: _state,
        onTap: _onTap,
        targets: _input.targets,
        arrowFrom: arrow?.from,
        arrowTo: arrow?.to,
        labels: _brilliantSquare == null
            ? const <BoardLabel>[]
            : <BoardLabel>[
                BoardLabel(square: _brilliantSquare!, text: '!! Brilliant'),
              ],
      ),
      feedback: _feedback,
      feedbackColor: _feedbackColor,
      solution: (line != null && line.isNotEmpty)
          ? SolutionCard(
              children: [
                Text(
                  'الحل: $line',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            )
          : null,
      actionsInOneRow: true,
      actions: [
        OutlinedButton(
          style: _kRowBtnStyle,
          onPressed: (_busy || _finished) ? null : _hint,
          child: const _BtnLabel('تلميح'),
        ),
        FilledButton.tonal(
          style: _kRowBtnStyle,
          onPressed: (_busy || _finished) ? null : _reveal,
          child: const _BtnLabel('أرني الحل'),
        ),
        OutlinedButton(
          style: _kRowBtnStyle,
          onPressed: _busy ? null : _loadCurrent,
          child: const _BtnLabel('أعد المحاولة'),
        ),
        // لا ينتقل للتالي قبل إنهاء اللغز.
        FilledButton(
          style: _kRowBtnStyle,
          onPressed: (_finished && _items.length > 1) ? _goNextUnsolved : null,
          child: const _BtnLabel('التالي'),
        ),
      ],
    );
  }
}


const ButtonStyle _kRowBtnStyle = ButtonStyle(
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: 4, vertical: 12),
  ),
  minimumSize: WidgetStatePropertyAll<Size>(Size(0, 44)),
);

/// نص زر يتقلّص ليتّسع في صف واحد على الشاشات الضيقة.
class _BtnLabel extends StatelessWidget {
  final String text;

  const _BtnLabel(this.text);

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1),
      );
}

// ================================================================
// مسار المستويات
// ================================================================

/// بداية تقييم كل مستوى (مبتدئ → جراند ماستر). المستويات الصغيرة
/// (أقل من [_kNeedPerLevel] لغزًا) تُدمج تلقائيًا.
const List<int> _kBandStarts = <int>[0, 1000, 1300, 1600, 1900, 2200, 2500];

/// عدد الألغاز اللازم حلّها في المستوى لفتح الذي بعده.
const int _kNeedPerLevel = 50;

const List<String> _kLevelNames = <String>[
  'مبتدئ',
  'أساسي',
  'متوسط',
  'متقدم',
  'خبير',
  'ماستر',
  'جراند ماستر',
];

class _LevelInfo {
  final String name;
  final String range;
  final int done;
  final int need;
  final bool unlocked;

  const _LevelInfo({
    required this.name,
    required this.range,
    required this.done,
    required this.need,
    required this.unlocked,
  });

  bool get complete => need > 0 && done >= need;

  double get fill => need == 0 ? 0 : (done / need).clamp(0.0, 1.0);
}

String _prefixFor(PuzzleCategory c) {
  switch (c) {
    case PuzzleCategory.mate:
      return '# ';
    case PuzzleCategory.brilliant:
      return '!! ';
    case PuzzleCategory.training:
      return '♟ ';
  }
}

String _suffixFor(PuzzleCategory c) {
  switch (c) {
    case PuzzleCategory.mate:
      return 'Checkmate';
    case PuzzleCategory.brilliant:
      return 'Brilliant';
    case PuzzleCategory.training:
      return 'Puzzles';
  }
}

/// ترويسة صفحة الألغاز: العنوان + بطاقة المستوى الحالي + مسار من
/// سبعة مقاطع (مقطع لكل مستوى) يمكن لمس أي مقطع مفتوح للانتقال إليه.
class _LevelHeader extends StatelessWidget {
  final PuzzleCategory category;
  final Color accent;
  final int level;
  final List<_LevelInfo> infos;
  final VoidCallback onOpenSheet;

  const _LevelHeader({
    required this.category,
    required this.accent,
    required this.level,
    required this.infos,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    if (infos.isEmpty || level >= infos.length) {
      return const SizedBox.shrink();
    }

    final cur = infos[level];
    final last = level == infos.length - 1;

    final String hint;

    if (last) {
      hint = cur.complete ? 'أكملت المسار 👑' : 'لإكمال المسار';
    } else {
      hint = cur.complete ? 'المستوى التالي مفتوح ✓' : 'للمستوى التالي';
    }

    const titleStyle = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الصف العلوي: رجوع (يمين) — العنوان — خيارات (يسار).
        Row(
          children: [
            IconButton(
              tooltip: 'رجوع',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _prefixFor(category),
                      style: titleStyle.copyWith(color: accent),
                    ),
                    TextSpan(
                      text: 'ألغاز ',
                      style: titleStyle.copyWith(color: Colors.white),
                    ),
                    TextSpan(
                      text: _suffixFor(category),
                      style: titleStyle.copyWith(color: accent),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const BoardOptionsButton(),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFF161A24),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpenSheet,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _LevelBadge(
                        label: '${level + 1}',
                        accent: accent,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cur.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (cur.range.isNotEmpty)
                              Text(
                                'تقييم ${cur.range}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${cur.done > cur.need ? cur.need : cur.done}'
                            '/${cur.need}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            hint,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more_rounded,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProgressBar(fill: cur.fill, accent: accent),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// شريط تقدم واحد متصل نحو المستوى التالي.
class _ProgressBar extends StatelessWidget {
  final double fill;
  final Color accent;

  const _ProgressBar({required this.fill, required this.accent});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fill),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(accent, Colors.white, 0.25)!,
                      accent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final String label;
  final Color accent;
  final double size;
  final IconData? icon;

  const _LevelBadge({
    required this.label,
    required this.accent,
    required this.size,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, 0.35)!,
            accent,
          ],
        ),
      ),
      child: icon != null
          ? Icon(icon, color: Colors.black87, size: size * 0.5)
          : Text(
              label,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.42,
              ),
            ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final int index;
  final _LevelInfo info;
  final bool current;
  final Color accent;
  final String previousName;
  final VoidCallback onTap;

  const _LevelRow({
    required this.index,
    required this.info,
    required this.current,
    required this.accent,
    required this.previousName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = !info.unlocked;

    final Widget trailing;

    if (current) {
      trailing = Icon(Icons.radio_button_checked_rounded, color: accent);
    } else if (locked) {
      trailing = const SizedBox.shrink();
    } else if (info.complete) {
      trailing = Icon(Icons.check_circle_rounded, color: accent);
    } else {
      trailing = Text(
        '${info.done}/${info.need}',
        style: TextStyle(color: accent, fontWeight: FontWeight.w800),
      );
    }

    final subtitle = locked
        ? 'أنهِ ${info.need} ألغاز من $previousName'
        : (info.range.isEmpty ? '' : 'تقييم ${info.range}');

    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Material(
        color: current ? accent.withValues(alpha: 0.14) : const Color(0xFF161A24),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: current ? accent : Colors.white12,
                width: current ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                locked
                    ? Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white12,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                      )
                    : _LevelBadge(
                        label: '${index + 1}',
                        accent: accent,
                        size: 40,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

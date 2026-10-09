import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'board_input.dart';
import 'lichess_puzzles.dart';
import 'models.dart';
import 'sound_service.dart';
import 'uci_utils.dart';

/// شاشة ألغاز Lichess (متعددة الخطوات) — تُستخدم لصفحتي
/// "ألغاز بريليانت" و"ألغاز جيك ميت" بحسب [category].
///
/// آلية اللغز (صيغة Lichess):
///  1. تُلعب نقلة الخصم الأولى تلقائيًا.
///  2. اللاعب يجد النقلة الصحيحة، ثم يردّ الخصم تلقائيًا، وهكذا حتى
///     نهاية الخط.
///  3. في ألغاز جيك ميت تُقبل أي نقلة تُنهي المباراة بكش مات حتى لو
///     كانت غير النقلة المسجّلة (كما يفعل Lichess).
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

  bool get _isMate => widget.category == PuzzleCategory.mate;

  String get _title => _isMate ? 'ألغاز جيك ميت' : 'ألغاز بريليانت';

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
    final items = await LichessPuzzleRepository.loadCategory(widget.category);
    final solved = await LichessPuzzleRepository.loadSolved();

    if (!mounted) return;

    // نبدأ من أول لغز غير محلول.
    var start = items.indexWhere((p) => !solved.contains(p.id));

    if (start < 0) start = 0;

    setState(() {
      _items = items;
      _solved = solved;
      _index = start;
      _loading = false;
    });

    unawaited(_loadCurrent());
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
    final acceptsAsMate = _isMate && _isCheckmate();

    if (matchesLine || acceptsAsMate) {
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

    setState(() => _busy = false);
  }

  Future<void> _onSolved(LichessPuzzle p) async {
    // لا نحتسب اللغز محلولًا إن كُشف الحل.
    final counted = !_revealed;

    setState(() {
      _finished = true;
      _busy = false;
      _hintUci = null;
      _feedback = _isMate ? 'كش مات! أحسنت ✅' : 'أحسنت! حللت اللغز ✅';
      _feedbackColor = AppColors.success;

      if (counted) _solved = <String>{..._solved, p.id};
    });

    if (counted) await LichessPuzzleRepository.markSolved(p.id);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          p == null ? _title : '$_title ${_index + 1} / ${_items.length}',
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : (p == null ? _buildEmpty() : _buildPuzzle(p)),
      ),
    );
  }

  Widget _buildEmpty() => const CenteredMessage('تعذّر تحميل الألغاز.');

  String _tagsLine(LichessPuzzle p) {
    final mateIn = p.mateIn;

    return <String>[
      'صعوبة ${p.rating}',
      if (mateIn != null) 'كش مات في $mateIn',
      if (p.sacrifice) 'تضحية',
      if (_solved.contains(p.id)) 'محلول ✓',
    ].join(' • ');
  }

  Widget _buildPuzzle(LichessPuzzle p) {
    final sideName = p.solverSide == 'w' ? 'الأبيض' : 'الأسود';

    final goal = _isMate ? 'أنهِ المباراة بكش مات' : 'اعثر على النقلة البريليانت';

    final arrow = parseUci(_hintUci);

    final solvedCount = _items.where((e) => _solved.contains(e.id)).length;

    final line = _solutionText;

    return PuzzleLayout(
      title: 'الدور على $sideName — $goal',
      subtitle:
          '${_tagsLine(p)}  —  حُلّ $solvedCount من ${_items.length}',
      board: AppBoard(
        state: _state,
        onTap: _onTap,
        targets: _input.targets,
        arrowFrom: arrow?.from,
        arrowTo: arrow?.to,
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
      actions: [
        OutlinedButton(
          onPressed: _items.length > 1 ? () => _go(-1) : null,
          child: const Text('السابق'),
        ),
        if (!_finished)
          OutlinedButton(
            onPressed: _busy ? null : _hint,
            child: const Text('تلميح'),
          ),
        if (!_finished)
          FilledButton.tonal(
            onPressed: _busy ? null : _reveal,
            child: const Text('أرني الحل'),
          ),
        OutlinedButton(
          onPressed: _loadCurrent,
          child: const Text('أعد المحاولة'),
        ),
        FilledButton(
          onPressed: _items.length > 1
              ? (_finished ? _goNextUnsolved : () => _go(1))
              : null,
          child: const Text('التالي'),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads_service.dart';
import 'analysis_controller.dart';
import 'analysis_result.dart';
import 'analysis_rules.dart';
import 'app_top_bar.dart';
import 'app_ui.dart';
import 'analysis_mode.dart';
import 'board_options.dart';
import 'board_widget.dart';
import 'game_review_models.dart';
import 'l10n.dart';
import 'lichess_data_service.dart';
import 'models.dart';
import 'piece_painter.dart';
import 'pgn_utils.dart';
import 'pv_utils.dart';
import 'source_style.dart';
import 'uci_utils.dart';

part 'game_analysis_stats.dart';
part 'game_analysis_summary.dart';
part 'game_analysis_review.dart';
part 'game_analysis_report.dart';
part 'game_analysis_lists.dart';
part 'game_analysis_widgets.dart';

/// شاشة تحليل مباراة واحدة — **مصدر واحد للتحليل** تُستخدم من
/// Chess.com ومن Lichess ومن PGN مُلصَق يدويًا على حدٍّ سواء.
/// كل ما تحتاجه هو نص PGN، وتسميات اختيارية لعرضها في الترويسة.
class GameAnalysisScreen extends StatefulWidget {
  final String pgn;
  final String? whiteLabel;
  final String? blackLabel;
  final String? resultLabel;
  final String sourceLabel;

  /// نوع التحليل: سريع (الافتراضي) أو PRO.
  final AnalysisMode mode;

  /// true إن كان اللاعب المبحوث عنه بالأسود: نقلب الرقعة ليظهر في الأسفل.
  final bool playerIsBlack;

  const GameAnalysisScreen({
    super.key,
    required this.pgn,
    this.whiteLabel,
    this.blackLabel,
    this.resultLabel,
    this.sourceLabel = '',
    this.mode = AnalysisMode.quick,
    this.playerIsBlack = false,
  });

  @override
  State<GameAnalysisScreen> createState() =>
      _GameAnalysisScreenState();
}

// ألوان شاشة التحليل (نفس نمط شاشات المصادر).
const Color _bg = SourceStyle.bg;
const Color _panel = SourceStyle.panel;
const Color _green = SourceStyle.green;

class _GameAnalysisScreenState
    extends State<GameAnalysisScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // خط التحليل كله في GameAnalysisController (انظر
  // analysis_controller.dart)؛ الواجهة تقرأ حالته فقط.
  // ============================================================

  late final GameAnalysisController _c = GameAnalysisController(
    pgn: widget.pgn,
    whiteLabel: widget.whiteLabel,
    blackLabel: widget.blackLabel,
    depth: widget.mode.depth,
    useCloud: widget.mode.useCloud,
  );

  String? get _parseError => _c.parseError;
  List<PgnPly> get _plies => _c.plies;
  List<String> get _fens => _c.fens;
  Map<String, String> get _headers => _c.headers;
  List<double> get _evalPawns => _c.evalPawns;
  List<String> get _evalLabels => _c.evalLabels;
  List<String> get _bestUci => _c.bestUci;
  List<List<String>> get _pvUci => _c.pvUci;
  List<MoveQuality> get _qualities => _c.qualities;
  List<bool> get _isBestEngineMove => _c.isBestEngineMove;
  List<int?> get _moveGapCp => _c.moveGapCp;
  List<int?> get _tbWdlWhite => _c.tbWdlWhite;
  List<BookMoveInfo?> get _bookInfo => _c.bookInfo;
  int get _puzzlesAdded => _c.puzzlesAdded;
  bool get _analyzing => _c.analyzing;
  bool get _cancelled => _c.cancelled;
  bool get _servedFromCache => _c.servedFromCache;
  double get _progress => _c.progress;
  int get _analyzedCount => _c.analyzedCount;

  int _cpAt(int i) => _c.cpAt(i);
  int _lossAt(int i) => _c.lossAt(i);
  double _accuracyAt(int i) => _c.accuracyAt(i);
  String _phaseOf(int plyIndex) => _c.phaseOf(plyIndex);
  void _cancelAnalysis() => _c.cancel();

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _c.addListener(_onControllerChanged);

    if (_c.parseError != null) return;

    _boardState.loadFen(_c.fens.first);

    if (widget.playerIsBlack) _boardState.flipBoard();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.start();
    });
  }

  final GameState _boardState = GameState();
  // مفتاح ثابت يمنع Flutter من تبديل عنصر الرقعة عند تحديثات التحليل.
  final GlobalKey _analysisBoardKey = GlobalKey();

  late final TabController _tabController =
      TabController(length: 5, vsync: this);

  int _currentIndex = 0;

  // خيارات العرض (قائمة الخيارات).
  bool _showArrows = true;
  bool _showEval = true;
  bool _showCoords = true;
  bool _showBadges = true;

  // false = نعرض شاشة التحليل ثم صفحة الإحصائيات؛ true = المراجعة
  // على الرقعة (الأسهم والعلامات لا تظهر قبل ذلك أبدًا).
  bool _reviewStarted = false;

  // شريط النقلات الأفقي + نافذة المراجعة.
  final ScrollController _stripCtrl = ScrollController();
  final Map<int, GlobalKey> _stripKeys = <int, GlobalKey>{};
  final ValueNotifier<int> _sheetTick = ValueNotifier<int>(0);
  bool _sheetOpen = false;
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);

    // يُحدّث محتوى نافذة المراجعة المفتوحة أثناء التحليل.
    _sheetTick.value++;
  }

  /// setState للاستدعاء من أجزاء الملف (extensions)، لأن setState
  /// محمية ولا يجوز استدعاؤها من خارج الصنف.
  void _update(VoidCallback fn) => setState(fn);

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    _boardState.dispose();
    _tabController.dispose();
    _stripCtrl.dispose();
    _sheetTick.dispose();
    super.dispose();
  }

  String get _whiteName =>
      widget.whiteLabel ?? _headers['White'] ?? tr('أبيض');

  String get _blackName =>
      widget.blackLabel ?? _headers['Black'] ?? tr('أسود');

  String get _resultText =>
      widget.resultLabel ?? _headers['Result'] ?? '';

  // ------------------------------------------------------------
  // ملاحظة التمارين المضافة من هذه المباراة
  // ------------------------------------------------------------

  Widget _buildPuzzlesNote() {
    if (_puzzlesAdded <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tr('أُضيف {puzzlesAdded} تمرين من هذه المباراة إلى «تمارين '
        'من مبارياتك».', {'puzzlesAdded': _puzzlesAdded}),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  String? _tbNoteAt(int k) {
    if (k < 0 ||
        k >= _plies.length ||
        k + 1 >= _tbWdlWhite.length) {
      return null;
    }

    final after = _tbWdlWhite[k + 1];

    if (after == null) return null;

    final sign = _plies[k].color == 'w' ? 1 : -1;

    String name(int v) =>
        v > 0 ? tr('فوز') : (v < 0 ? tr('خسارة') : tr('تعادل'));

    final ma = after * sign;
    final beforeRaw = _tbWdlWhite[k];

    if (beforeRaw == null) {
      return tr('Tablebase: النتيجة بعد النقلة مضمونة — {v}', {'v': name(ma)});
    }

    final mb = beforeRaw * sign;

    if (mb == ma) {
      return tr('Tablebase: النتيجة لم تتغير ({v} مضمون)', {'v': name(mb)});
    }

    return tr('Tablebase: {v} ← {v2} (نتيجة مضمونة)', {'v': name(mb), 'v2': name(ma)});
  }

  String? _bookNoteAt(int k) {
    if (k < 0 || k >= _bookInfo.length) return null;

    final info = _bookInfo[k];

    if (info == null) return null;

    final parts = <String>[];

    if (info.mastersGames > 0) {
      final pct = info.mastersPercent;

      parts.add(
        tr('لُعبت في {mastersGames} مباراة أساتذة'
        '{v}', {'mastersGames': info.mastersGames, 'v': pct != null ? ' (${pct.toStringAsFixed(0)}%)' : ''}),
      );
    }

    final lp = info.lichessPercent;

    if (lp != null && (info.lichessGames ?? 0) > 0) {
      parts.add(
        tr('يلعبها {v}% من لاعبي Lichess', {'v': lp.toStringAsFixed(0)}),
      );
    }

    if (parts.isEmpty) return null;

    return '${info.isBook ? tr('كتاب: ') : ''}${parts.join(' · ')}';
  }

  /// لاحقة تقليدية (?, ??, ?!, !!) تُضاف لنص SAN، بنفس أسلوب
  /// الأمثلة المرفقة في الطلب.
  String _sanSuffix(MoveQuality q) {
    switch (q) {
      case MoveQuality.brilliant:
        return '!!';
      case MoveQuality.great:
        return '!';
      case MoveQuality.inaccuracy:
        return '?!';
      case MoveQuality.mistake:
      case MoveQuality.miss:
        return '?';
      case MoveQuality.blunder:
        return '??';
      default:
        return '';
    }
  }

  // ============================================================
  // التنقل بين النقلات
  // ============================================================

  void _goTo(int index) {
    if (_fens.isEmpty) {
      return;
    }

    final clamped = index.clamp(0, _fens.length - 1);

    setState(() {
      _currentIndex = clamped;
    });

    _boardState.loadFen(_fens[clamped]);

    _scrollStripToCurrent();
  }

  /// ينتقل إلى النقلة رقم [index] ويحوّل التبويب إلى "نظرة
  /// عامة" حتى تظهر الرقعة والسهم مباشرة (يُستخدم من تبويبي
  /// الأخطاء واللحظات الحرجة).
  void _jumpAndShowBoard(int index) {
    _goTo(index);

    if (_sheetOpen && mounted) {
      _sheetOpen = false;
      Navigator.of(context).pop();
    }
  }

  /// السهم يُبنى مباشرة من UCI (من → إلى) عبر طبقة UCI الموحدة،
  /// وليس من SAN أو من نص معروض. يعيد null إن كان UCI غير صالح.
  BoardArrow? _decodeArrow(String uci, Color color) {
    final move = parseUci(uci);

    if (move == null) return null;

    return BoardArrow(
      from: move.from,
      to: move.to,
      color: color,
    );
  }

  /// سهم واحد فقط: أفضل نقلة يقترحها المحرك. لا نرسم أبدًا سهم
  /// النقلة التي لُعبت، ولا نرسم شيئًا قبل الضغط على "متابعة
  /// المراجعة".
  List<BoardArrow> _arrowsForCurrent() {
    if (!_reviewStarted ||
        _plies.isEmpty ||
        _fens.isEmpty) {
      return const <BoardArrow>[];
    }

    final k = _currentIndex - 1;

    // الوضعية الابتدائية: أفضل نقلة للأبيض.
    final idx = _currentIndex == 0 ? 0 : k;

    if (_currentIndex > 0) {
      if (k >= _qualities.length ||
          k >= _isBestEngineMove.length) {
        return const <BoardArrow>[];
      }

      // لعب الأفضل أو نقلة كتاب: لا حاجة لسهم.
      if (_isBestEngineMove[k] ||
          _qualities[k] == MoveQuality.book) {
        return const <BoardArrow>[];
      }
    }

    if (idx >= _bestUci.length) {
      return const <BoardArrow>[];
    }

    final arrow = _decodeArrow(
      _bestUci[idx],
      const Color(0xFF81B64C).withValues(alpha: 0.9),
    );

    return arrow == null ? const <BoardArrow>[] : <BoardArrow>[arrow];
  }

  /// علامة جودة النقلة فوق القطعة المتحركة (الزاوية العلوية
  /// اليمنى) — بعد بدء المراجعة فقط.
  List<BoardBadge> _badgesForCurrent() {
    if (!_reviewStarted || !_showBadges || _currentIndex <= 0) {
      return const <BoardBadge>[];
    }

    final k = _currentIndex - 1;

    if (k >= _qualities.length || k >= _plies.length) {
      return const <BoardBadge>[];
    }

    return [
      BoardBadge(
        square: _plies[k].to,
        quality: _qualities[k],
      ),
    ];
  }

  // ============================================================
  // Build
  // ============================================================

  // ============================================================
  // واجهة بأسلوب تطبيق Chess.com — شاشة واحدة
  // ============================================================


  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: _green,
      scaffoldBackgroundColor: _bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_parseError != null) {
      return Theme(
        data: _darkTheme(),
        child: Scaffold(
          appBar: const AppTopBar(title: 'تحليل المباراة'),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _parseError!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_reviewStarted) {
      return Theme(
        data: _darkTheme(),
        child: Scaffold(
          backgroundColor: _bg,
          appBar: const AppTopBar(title: 'مراجعة المباراة'),
          body: SafeArea(
            child: _analyzing
                ? _buildAnalyzingView()
                : _buildSummaryView(),
          ),
        ),
      );
    }

    final topColor = _boardState.flipped ? 'w' : 'b';
    final bottomColor = _boardState.flipped ? 'b' : 'w';

    return Theme(
      data: _darkTheme(),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppTopBar(
          title: widget.sourceLabel.isEmpty
              ? 'تحليل المباراة'
              : widget.sourceLabel,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              // الأجزاء الثابتة: الشريط العلوي + النقلات + التقييم
              // + لاعبان + الشريط السفلي + حد أدنى للمعلومات.
              const fixed = 30 + 46 + 16 + 120 + 78 + 70;

              final side = math.min(
                c.maxWidth,
                math.max(180.0, c.maxHeight - fixed),
              );

              return Column(
                children: [
                  _buildTopBar(),
                  const AdBanner(),
                  _buildMoveStrip(),
                  if (_showEval) _buildEvalStrip(),
                  _buildPlayerBar(topColor),
                  Center(
                    child: SizedBox(
                      width: side,
                      height: side,
                      child: _buildBoard(),
                    ),
                  ),
                  _buildPlayerBar(bottomColor),
                  Expanded(child: _buildInfoPanel()),
                  _buildBottomBar(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }


  // ============================================================
  // مرحلة 1: التحليل  →  مرحلة 2: صفحة الإحصائيات  →  المراجعة
  // ============================================================

  void _startReview({int index = 0}) {
    setState(() {
      _reviewStarted = true;
    });

    _goTo(index);
  }

}
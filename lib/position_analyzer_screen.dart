import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as ch;

import 'app_settings.dart';
import 'app_ui.dart';
import 'board_options.dart';
import 'engine_service.dart';
import 'models.dart';
import 'panels.dart';
import 'position_insights.dart';
import 'sound_service.dart';
import 'uci_utils.dart';

/// ============================================================
/// Position Analyzer Screen (وضعية خاصة)
/// ============================================================

class PositionAnalyzerScreen extends StatefulWidget {
  const PositionAnalyzerScreen({
    super.key,
  });

  @override
  State<PositionAnalyzerScreen> createState() =>
      _PositionAnalyzerScreenState();
}

class _PositionAnalyzerScreenState extends State<PositionAnalyzerScreen> {
  // ==========================================================
  // State
  // ==========================================================

  final GameState state =
      GameState();

  final EngineService engine =
      EngineService();

  final SoundService soundService =
      SoundService();

  String engineStatus =
      '🟡 جاري تشغيل Stockfish 19...';

  bool engineReady = false;

  int depth = 18;
  int multiPv = 3;

  final Map<int, PvLineDisplay> pvLines =
      <int, PvLineDisplay>{};

  String? _analysisFen;
  String? _lastKnownFen;

  String? selectedSetupPiece;

  bool eraseMode = false;

  Set<String> targets =
      <String>{};

  // ==========================================================
  // Init
  // ==========================================================

  @override
  void initState() {
    super.initState();

    state.addListener(
      _onStateChanged,
    );

    AppSettings.instance.addListener(_onSettingsChanged);

    state.onSound = (
      String kind,
    ) {
      soundService.playKind(kind);
    };

    engine.onStatus = (
      String status,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        engineStatus = status;

        // ملاحظة: لا نستنتج جاهزية المحرك من شكل
        // الرسالة (🟢/🟡/🔴)، لأن رسائل مثل "تم إيقاف
        // التحليل" أو "جاري تحليل الوضعية..." تبدأ بـ
        // 🟡 رغم أن المحرك لا يزال جاهزًا تمامًا. كان
        // هذا يجعل زر "تحليل الوضعية" يتعطل بشكل دائم
        // بعد أول إيقاف للتحليل. نعتمد بدلاً من ذلك على
        // العلم الفعلي engine.ready الذي تديره
        // EngineService نفسها.
        engineReady =
            engine.ready;
      });
    };

    engine.onInfoFor = (
      AnalysisRequest request,
      int multipv,
      PvLine raw,
    ) {
      if (!mounted) {
        return;
      }

      // النتيجة تُطبَّق فقط إذا كان طلبها هو آخر طلب وما زالت
      // الرقعة على نفس الوضعية.
      final analysisFen = request.fen;

      if (_analysisFen == null ||
          _analysisFen!.trim() != analysisFen.trim() ||
          analysisFen.trim() != state.currentFen.trim()) {
        return;
      }

      final display =
          _convertPv(
        analysisFen,
        raw,
      );

      // لا نعرض PV إذا لم نستطع
      // تحويل أول نقلة إلى نقلة قانونية.
      if (display.moves.isEmpty ||
          display.bestFrom.isEmpty ||
          display.bestTo.isEmpty) {
        return;
      }

      setState(() {
        pvLines[multipv] =
            display;
      });
    };

    engine.onBestMoveFor = (
      AnalysisRequest request,
      String uci,
    ) {
      // بعض إصدارات/بناءات Stockfish قد ترسل bestmove
      // بدون أن تصل آخر info/pv إلى EventChannel.
      // في هذه الحالة نستخدم bestmove نفسه كحل احتياطي
      // حتى لا ينتهي التحليل بواجهة فارغة وبدون سهم.
      if (!mounted) {
        return;
      }

      final analysisFen = request.fen;
      if (_analysisFen == null ||
          _analysisFen!.trim() != analysisFen.trim() ||
          analysisFen.trim() != state.currentFen.trim()) {
        return;
      }

      final best = parseUci(uci);
      if (best == null) {
        return;
      }

      // إذا وصل PV بالفعل، فلا نستبدله.
      if (pvLines.containsKey(1)) {
        return;
      }

      setState(() {
        pvLines[1] = PvLineDisplay(
          depth: depth,
          evalLabel: '—',
          moves: <String>[best.uci],
          bestFrom: best.from,
          bestTo: best.to,
        );
      });
    };

    // تشغيل Stockfish 19.
    engine.init();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  /// تنفيذ نقلة UCI على الرقعة (عند لمس نقلة في الكتاب أو Maia أو
  /// Tablebase).
  void _playUci(String uci) {
    final move = parseUci(uci);

    if (state.mode != 'play' || move == null) {
      return;
    }

    setState(() {
      targets = <String>{};
    });

    state.tapSetupSelect(null);

    state.tryMove(
      move.from,
      move.to,
      promotion: move.promotion,
    );
  }

  // ==========================================================
  // State changes
  // ==========================================================

  void _onStateChanged() {
    if (!mounted) {
      return;
    }

    final fen =
        state.currentFen.trim();

    if (fen != _lastKnownFen) {
      _lastKnownFen = fen;

      if (engine.analyzing) {
        engine.stop();
      }

      setState(() {
        pvLines.clear();

        _analysisFen = null;

        targets =
            <String>{};
      });

      return;
    }

    setState(() {});
  }

  // ==========================================================
  // Dispose
  // ==========================================================

  @override
  void dispose() {
    state.removeListener(
      _onStateChanged,
    );

    AppSettings.instance.removeListener(_onSettingsChanged);

    engine.dispose();

    soundService.dispose();

    state.dispose();

    super.dispose();
  }

  // ==========================================================
  // Convert UCI PV to SAN
  // ==========================================================

  PvLineDisplay _convertPv(
    String fen,
    PvLine raw,
  ) {
    final chess =
        ch.Chess();

    try {
      final loaded =
          chess.load(fen);

      if (loaded == false) {
        return PvLineDisplay(
          depth: raw.depth,
          evalLabel: raw.evalLabel,
          moves: const <String>[],
          bestFrom: '',
          bestTo: '',
        );
      }
    } catch (_) {
      return PvLineDisplay(
        depth: raw.depth,
        evalLabel: raw.evalLabel,
        moves: const <String>[],
        bestFrom: '',
        bestTo: '',
      );
    }

    final List<String> sans =
        <String>[];

    String bestFrom = '';
    String bestTo = '';

    for (final uciRaw
        in raw.uciMoves) {
      // أهم نقطة: لا نجعل فشل تحويل SAN يمنع ظهور
      // نتيجة Stockfish والسهم. UCI نفسه كافٍ لرسم السهم.
      final move = parseUci(uciRaw);

      if (move == null) {
        break;
      }

      final uci = move.uci;
      final from = move.from;
      final to = move.to;
      final String? promotion = move.promotion;

      // ------------------------------------------------------
      // النقلة الأولى تُستخدم للسهم فورًا.
      // ------------------------------------------------------

      if (bestFrom.isEmpty) {
        bestFrom = from;
        bestTo = to;
      }

      // ------------------------------------------------------
      // البحث عن النقلة بين النقلات القانونية للحصول على SAN،
      // ثم تنفيذها على نسخة التحليل لمتابعة الـ PV.
      // إذا فشل ذلك نعرض UCI بدل إسقاط النتيجة كلها.
      // ------------------------------------------------------

      final legal = GameState.findLegalMove(
        chess,
        from,
        to,
        promotion,
      );

      if (legal == null) {
        if (sans.isEmpty) {
          sans.add(uci);
        }
        break;
      }

      final san = (legal['san'] ?? uci).toString();

      bool moved = false;
      try {
        final args = <String, dynamic>{
          'from': from,
          'to': to,
        };
        if (promotion != null) {
          args['promotion'] = promotion;
        }
        final result = chess.move(args);
        moved = result != false;
      } catch (_) {
        moved = false;
      }

      if (!moved) {
        if (sans.isEmpty) {
          sans.add(uci);
        }
        break;
      }

      sans.add(san);

      // لا نعرض أكثر من 8 نقلات.
      if (sans.length >= 8) {
        break;
      }
    }

    return PvLineDisplay(
      depth: raw.depth,
      evalLabel: raw.evalLabel,
      moves: List<String>.unmodifiable(
        sans,
      ),
      bestFrom: bestFrom,
      bestTo: bestTo,
    );
  }

  // ==========================================================
  // Analyze
  // ==========================================================

  void _analyze() {
    final fen =
        state.currentFen.trim();

    if (fen.isEmpty) {
      return;
    }

    if (!engineReady) {
      showAppSnack(context, 'Stockfish 19 لم يصبح جاهزًا بعد');

      return;
    }

    setState(() {
      pvLines.clear();

      _analysisFen = fen;
    });

    engine.analyze(
      fen,
      depth: depth,
      multiPv: multiPv,
    );
  }

  // ==========================================================
  // Promotion dialog
  // ==========================================================

  Future<String?> _askPromotion() {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'اختر قطعة الترقية',
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p
                  in <String>[
                'q',
                'r',
                'b',
                'n',
              ])
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      p,
                    );
                  },
                  child: Text(
                    <String, String>{
                      'q': 'وزير',
                      'r': 'رخ',
                      'b': 'فيل',
                      'n': 'حصان',
                    }[p]!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // Board tap
  // ==========================================================

  Future<void> _onBoardTap(
    String square,
  ) async {
    // --------------------------------------------------------
    // Setup mode
    // --------------------------------------------------------

    if (state.mode == 'setup') {
      if (eraseMode) {
        state.eraseSetupSquare(
          square,
        );

        return;
      }

      if (selectedSetupPiece != null) {
        state.placeSetupPiece(
          square,
          selectedSetupPiece!,
        );

        return;
      }

      state.tapSetupSelect(
        square ==
                state.selectedSquare
            ? null
            : square,
      );

      return;
    }

    // --------------------------------------------------------
    // Play mode
    // --------------------------------------------------------

    if (state.selectedSquare == null) {
      final board =
          GameState.parseBoard(
        state.currentFen
            .split(' ')
            .first,
      );

      final piece =
          board[square];

      final fenParts =
          state.currentFen
              .split(' ');

      final turn =
          fenParts.length > 1
              ? fenParts[1]
              : 'w';

      if (piece != null &&
          piece.startsWith(turn)) {
        state.tapSetupSelect(
          square,
        );

        setState(() {
          targets =
              state
                  .legalTargets(square)
                  .toSet();
        });
      }

      return;
    }

    // --------------------------------------------------------
    // Same square
    // --------------------------------------------------------

    if (square ==
        state.selectedSquare) {
      state.tapSetupSelect(
        null,
      );

      setState(() {
        targets =
            <String>{};
      });

      return;
    }

    // --------------------------------------------------------
    // New piece selection
    // --------------------------------------------------------

    if (!targets.contains(square)) {
      final board =
          GameState.parseBoard(
        state.currentFen
            .split(' ')
            .first,
      );

      final piece =
          board[square];

      final fenParts =
          state.currentFen
              .split(' ');

      final turn =
          fenParts.length > 1
              ? fenParts[1]
              : 'w';

      if (piece != null &&
          piece.startsWith(turn)) {
        state.tapSetupSelect(
          square,
        );

        setState(() {
          targets =
              state
                  .legalTargets(square)
                  .toSet();
        });
      } else {
        state.tapSetupSelect(
          null,
        );

        setState(() {
          targets =
              <String>{};
        });
      }

      return;
    }

    // --------------------------------------------------------
    // Make move
    // --------------------------------------------------------

    final from =
        state.selectedSquare!;

    final board =
        GameState.parseBoard(
      state.currentFen
          .split(' ')
          .first,
    );

    final movingPiece =
        board[from];

    final isPromotion =
        movingPiece != null &&
        movingPiece.length >= 2 &&
        movingPiece.substring(1) ==
            'P' &&
        (
          (
            movingPiece.startsWith('w') &&
            square.endsWith('8')
          ) ||
          (
            movingPiece.startsWith('b') &&
            square.endsWith('1')
          )
        );

    setState(() {
      targets =
          <String>{};
    });

    if (isPromotion) {
      final promotion =
          await _askPromotion();

      if (!mounted) {
        return;
      }

      state.tryMove(
        from,
        square,
        promotion:
            promotion ?? 'q',
      );
    } else {
      state.tryMove(
        from,
        square,
      );
    }
  }

  // ==========================================================
  // Build
  // ==========================================================

  static const Color _accent = Color(0xFF4169FF);
  static const Color _page = Color(0xFF0E1118);
  static const Color _surface = Color(0xFF161A24);

  ThemeData _screenTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: _accent,
      scaffoldBackgroundColor: _page,
      appBarTheme: const AppBarTheme(
        backgroundColor: _page,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح الرقعة؟'),
        content: const Text('ستُزال كل القطع من الرقعة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (ok == true) state.clearBoardForSetup();
  }

  Widget _modeSwitch() {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      segments: const [
        ButtonSegment<String>(
          value: 'play',
          icon: Icon(Icons.sports_esports_rounded),
          label: Text('وضع اللعب'),
        ),
        ButtonSegment<String>(
          value: 'setup',
          icon: Icon(Icons.tune_rounded),
          label: Text('إعداد الوضعية'),
        ),
      ],
      selected: <String>{state.mode == 'setup' ? 'setup' : 'play'},
      onSelectionChanged: (s) {
        if (s.first == 'setup') {
          state.enterSetupModeFromCurrent();
        } else {
          state.enterPlayModeFromSetup();
        }
      },
    );
  }

  Widget _toolTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return Expanded(
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(color: color, fontSize: 12, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pieceTheme = AppSettings.instance.pieceTheme;

    final top = pvLines[1];

    return Theme(
      data: _screenTheme(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('وضعية خاصة'),
          actions: const [BoardOptionsButton()],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // الرقعة
                    AppBoard(
                      state: state,
                      onTap: _onBoardTap,
                      targets: targets,
                      arrowFrom: top != null && top.bestFrom.isNotEmpty
                          ? top.bestFrom
                          : null,
                      arrowTo: top != null && top.bestTo.isNotEmpty
                          ? top.bestTo
                          : null,
                    ),

                    const SizedBox(height: 12),

                    // تبديل الوضع: لعب / إعداد
                    _modeSwitch(),

                    const SizedBox(height: 10),

                    // أدوات الرقعة
                    Row(
                      children: [
                        _toolTile(
                          icon: Icons.flip_rounded,
                          label: 'قلب الرقعة',
                          onTap: state.flipBoard,
                        ),
                        const SizedBox(width: 8),
                        _toolTile(
                          icon: Icons.restart_alt_rounded,
                          label: 'الوضعية الابتدائية',
                          onTap: state.startPosition,
                        ),
                        const SizedBox(width: 8),
                        _toolTile(
                          icon: Icons.delete_outline_rounded,
                          label: 'مسح الرقعة',
                          color: Colors.redAccent,
                          onTap: _confirmClear,
                        ),
                      ],
                    ),

                    // لوحة القطع (في وضع الإعداد فقط)
                    if (state.mode == 'setup') ...[
                      const SizedBox(height: 12),
                      SetupPanel(
                        state: state,
                        pieceTheme: pieceTheme,
                        selectedPiece: selectedSetupPiece,
                        eraseMode: eraseMode,
                        onSelectPiece: (String piece) {
                          setState(() {
                            selectedSetupPiece = piece;
                            eraseMode = false;
                          });
                        },
                        onToggleErase: () {
                          setState(() {
                            eraseMode = !eraseMode;
                            selectedSetupPiece = null;
                          });
                        },
                        onChanged: () {},
                      ),
                    ],

                    const SizedBox(height: 12),

                    // التحليل
                    AnalysisPanel(
                      engineStatus: engineStatus,
                      engineReady: engineReady,
                      analyzing: engine.analyzing,
                      multiPv: multiPv,
                      lines: pvLines,
                      onAnalyze: _analyze,
                      onStop: () {
                        engine.stop();
                      },
                      onMultiPvChanged: (int value) {
                        setState(() {
                          multiPv = value;
                        });
                      },
                      onSelectLine: (int index) {
                        // لا نغير وضعية الرقعة عند اختيار PV.
                      },
                    ),

                    const SizedBox(height: 12),

                    // الكتاب + Tablebase + نقلات بشرية
                    PositionInsightsPanel(
                      fen: state.currentFen,
                      enabled: state.mode == 'play' && state.legal,
                      engineBestUci: top != null &&
                              top.bestFrom.isNotEmpty &&
                              top.bestTo.isNotEmpty
                          ? '${top.bestFrom}${top.bestTo}'
                          : null,
                      onPlayMove: _playUci,
                    ),

                    const SizedBox(height: 12),

                    // سجل النقلات
                    MoveListPanel(history: state.history),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

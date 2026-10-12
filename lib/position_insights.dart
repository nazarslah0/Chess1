import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'lichess_data_service.dart';
import 'uci_utils.dart';

/// مصادر إضافية لشاشة تحليل الوضعية، تُحدَّث تلقائيًا عند تغيّر
/// الوضعية: نقلات الكتاب (Opening Explorer)، نتيجة Tablebase المضمونة
/// (7 قطع أو أقل). وتُعلَّم بنجمة النقلة التي اختارها Stockfish.
class PositionInsightsPanel extends StatefulWidget {
  final String fen;

  /// false أثناء إعداد الوضعية أو إن كانت غير قانونية.
  final bool enabled;

  /// أفضل نقلة عند Stockfish (UCI) إن وُجدت.
  final String? engineBestUci;

  /// عند لمس نقلة في القوائم.
  final void Function(String uci) onPlayMove;

  const PositionInsightsPanel({
    super.key,
    required this.fen,
    required this.enabled,
    required this.onPlayMove,
    this.engineBestUci,
  });

  @override
  State<PositionInsightsPanel> createState() =>
      _PositionInsightsPanelState();
}

class _PositionInsightsPanelState extends State<PositionInsightsPanel> {
  Timer? _debounce;
  int _req = 0;

  // الكتاب
  ExplorerPositionData? _lichess;
  bool _bookLoading = false;
  bool _bookFailed = false;

  // Tablebase
  bool _tbEligible = false;
  bool _tbLoading = false;
  TablebaseDetail? _tb;

  @override
  void initState() {
    super.initState();

    // لا يجوز استدعاء setState داخل initState مباشرةً.
    Future<void>.microtask(() {
      if (mounted) _schedule();
    });
  }

  @override
  void didUpdateWidget(covariant PositionInsightsPanel old) {
    super.didUpdateWidget(old);

    if (old.fen != widget.fen || old.enabled != widget.enabled) {
      _schedule();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _req++;
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();

    final req = ++_req;

    if (!widget.enabled) {
      setState(() {
        _bookLoading = false;
        _tbLoading = false;
        _tbEligible = false;
        _tb = null;
        _lichess = null;
      });

      return;
    }

    setState(() {
      _bookLoading = true;
      _bookFailed = false;
      _tbEligible = TablebaseService.isEligible(widget.fen);
      _tbLoading = _tbEligible;
      _tb = null;
    });

    final fen = widget.fen;

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadBook(fen, req);

      if (_tbEligible) _loadTablebase(fen, req);
    });
  }

  // ------------------------------------------------------------
  // الجلب
  // ------------------------------------------------------------

  Future<void> _loadBook(String fen, int req) async {
    // الكتاب ثابت على قاعدة Lichess (بلا اختيار من الواجهة).
    final r = await OpeningExplorerService.instance.lichessStats(fen);

    if (!mounted || req != _req) return;

    setState(() {
      _lichess = r;
      _bookLoading = false;
      _bookFailed = r == null;
    });
  }

  Future<void> _loadTablebase(String fen, int req) async {
    final d = await TablebaseService.instance.probeDetailed(fen);

    if (!mounted || req != _req) return;

    setState(() {
      _tb = d;
      _tbLoading = false;
    });
  }

  bool _isEngineBest(String uci) {
    return isSameUciMove(widget.engineBestUci, uci);
  }

  // ------------------------------------------------------------
  // الواجهة
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        _buildBook(),
        if (_tbEligible) ...[
          const SizedBox(height: 12),
          _buildTablebase(),
        ],
      ],
    );
  }

  Widget _card(String title, Widget child, {Widget? trailing}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _hint(String text) => Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );

  Widget _star() => const Padding(
        padding: EdgeInsetsDirectional.only(start: 4),
        child: Icon(Icons.star_rounded, size: 16, color: Colors.amber),
      );

  static String _pct(double p) {
    final v = p * 100;

    return v < 1 ? '<1%' : '${v.toStringAsFixed(0)}%';
  }

  // ---------------- الكتاب ----------------

  Widget _buildBook() {
    final data = _lichess;

    Widget body;

    if (_bookLoading) {
      body = const LinearProgressIndicator();
    } else if (_bookFailed) {
      body = _hint(
        OpeningExplorerService.instance.lastError == 'unauthorized'
            ? tr('رفض Lichess الطلب — يلزم توكن شخصي مجاني '
                '(LICHESS_TOKEN، انظر README).')
            : tr('تعذّر جلب إحصائيات الكتاب.'),
      );
    } else if (data == null || data.total == 0 || data.moves.isEmpty) {
      body = _hint(tr('الوضعية خارج الكتاب في هذه القاعدة.'));
    } else {
      final top = data.moves.take(6).toList();

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hint(tr('{total} مباراة في هذه الوضعية', {'total': data.total})),
          const SizedBox(height: 6),
          for (final m in top) _bookRow(m, data.total),
        ],
      );
    }

    return _card(tr('الكتاب'), body);
  }

  Widget _bookRow(ExplorerMoveStat m, int positionTotal) {
    final share = positionTotal > 0 ? m.total / positionTotal : 0.0;
    final t = m.total == 0 ? 1 : m.total;

    return InkWell(
      onTap: parseUci(m.uci) != null
          ? () => widget.onPlayMove(m.uci)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Row(
                children: [
                  Text(
                    m.san,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textDirection: TextDirection.ltr,
                  ),
                  if (_isEngineBest(m.uci)) _star(),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                _pct(share),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      if (m.white > 0)
                        Expanded(
                          flex: (m.white * 1000 ~/ t).clamp(1, 1000),
                          child: Container(color: Colors.white),
                        ),
                      if (m.draws > 0)
                        Expanded(
                          flex: (m.draws * 1000 ~/ t).clamp(1, 1000),
                          child: Container(color: Colors.grey),
                        ),
                      if (m.black > 0)
                        Expanded(
                          flex: (m.black * 1000 ~/ t).clamp(1, 1000),
                          child: Container(color: Colors.black87),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              child: Text(
                '${m.total}',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Tablebase ----------------

  Widget _buildTablebase() {
    Widget body;

    final d = _tb;

    if (_tbLoading) {
      body = const LinearProgressIndicator();
    } else if (d == null) {
      body = _hint(tr('تعذّر جلب نتيجة Tablebase.'));
    } else {
      final turnWhite = widget.fen.split(' ').length > 1 &&
          widget.fen.split(' ')[1] == 'w';

      final side = turnWhite ? tr('الأبيض') : tr('الأسود');

      String headline;
      Color color;

      if (d.checkmate) {
        headline = tr('كش مات');
        color = Colors.red;
      } else if (d.stalemate) {
        headline = tr('ستاليمايت — تعادل');
        color = Colors.grey;
      } else if (d.result == 1) {
        headline = tr('فوز مضمون لـ{side}', {'side': side});
        color = Colors.green;
      } else if (d.result == -1) {
        headline = tr('خسارة مضمونة لـ{side}', {'side': side});
        color = Colors.red;
      } else if (d.result == 0) {
        headline = tr('تعادل مضمون');
        color = Colors.grey;
      } else {
        headline = tr('نتيجة غير حاسمة');
        color = Colors.grey;
      }

      final extra = <String>[
        if (d.dtm != null) tr('مات خلال {v} نقلة (DTM)', {'v': d.dtm!.abs()}),
        if (d.dtm == null && d.dtz != null) 'DTZ ${d.dtz!.abs()}',
      ];

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (extra.isNotEmpty) _hint(extra.join(' • ')),
          const SizedBox(height: 6),
          for (final m in d.moves.take(6)) _tbRow(m),
        ],
      );
    }

    return _card(tr('Tablebase (نتيجة مضمونة)'), body);
  }

  Widget _tbRow(TablebaseMove m) {
    IconData icon;
    Color color;
    String label;

    switch (m.result) {
      case 1:
        icon = Icons.emoji_events_rounded;
        color = Colors.green;
        label = tr('فوز');
        break;
      case 0:
        icon = Icons.balance_rounded;
        color = Colors.grey;
        label = tr('تعادل');
        break;
      case -1:
        icon = Icons.close_rounded;
        color = Colors.red;
        label = tr('خسارة');
        break;
      default:
        icon = Icons.help_outline_rounded;
        color = Colors.grey;
        label = tr('؟');
    }

    final dist = m.dtm != null
        ? 'DTM ${m.dtm!.abs()}'
        : (m.dtz != null ? 'DTZ ${m.dtz!.abs()}' : '');

    return InkWell(
      onTap: parseUci(m.uci) != null
          ? () => widget.onPlayMove(m.uci)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 74,
              child: Row(
                children: [
                  Text(
                    m.san,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textDirection: TextDirection.ltr,
                  ),
                  if (_isEngineBest(m.uci)) _star(),
                ],
              ),
            ),
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            const Spacer(),
            Text(
              dist,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

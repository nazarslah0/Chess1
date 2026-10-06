part of 'game_analysis_screen.dart';

// ================================================================
// نتيجة تقييم وضعية واحدة / لحظة حرجة
// ================================================================

class _CriticalMoment {
  final int plyIndex;
  final MoveQuality quality;
  final int lossCp;
  final double score;

  /// swing / only_move / tablebase
  final String kind;

  const _CriticalMoment({
    required this.plyIndex,
    required this.quality,
    required this.lossCp,
    this.score = 0,
    this.kind = 'swing',
  });
}

class _PhaseStat {
  final int moveCount;
  final double accuracy;
  final int errorCount;

  const _PhaseStat({
    required this.moveCount,
    required this.accuracy,
    required this.errorCount,
  });
}

// ================================================================
// الرسم البياني للتقييم — مرسوم يدويًا (CustomPainter) بدون أي
// مكتبة خارجية، مع دعم الضغط لأقرب نقطة نقلة كما طُلب صراحة.
// ================================================================

class _EvalGraph extends StatelessWidget {
  final List<double> evalPawns;
  final List<MoveQuality> qualities;
  final List<MoveAnalysisResult> moves;
  final int currentIndex;
  final void Function(int index) onSelect;

  const _EvalGraph({
    required this.evalPawns,
    required this.qualities,
    required this.moves,
    required this.currentIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (evalPawns.length < 2) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('لا توجد بيانات كافية للرسم.'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 140.0;

        void handleTap(Offset local) {
          final dx = local.dx.clamp(0, width);

          final idx = width <= 0
              ? 0
              : (dx / width * (evalPawns.length - 1))
                  .round()
                  .clamp(0, evalPawns.length - 1);

          onSelect(idx);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) =>
              handleTap(d.localPosition),
          onHorizontalDragUpdate: (d) =>
              handleTap(d.localPosition),
          child: CustomPaint(
            size: Size(width, height),
            painter: _EvalGraphPainter(
              evalPawns: evalPawns,
              qualities: qualities,
              moves: moves,
              currentIndex: currentIndex,
            ),
          ),
        );
      },
    );
  }
}

class _EvalGraphPainter extends CustomPainter {
  final List<double> evalPawns;
  final List<MoveQuality> qualities;
  final List<MoveAnalysisResult> moves;
  final int currentIndex;

  const _EvalGraphPainter({
    required this.evalPawns,
    required this.qualities,
    required this.moves,
    required this.currentIndex,
  });

  static const double _cap = 5.0;

  double _xAt(int i, int n, double width) =>
      n <= 1 ? 0 : (i / (n - 1)) * width;

  double _yAt(double pawns, double height) {
    final clamped = pawns.clamp(-_cap, _cap);
    final mid = height / 2;
    return mid - (clamped / _cap) * mid;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = evalPawns.length;

    if (n < 2) return;

    final mid = size.height / 2;

    // الخلفية: نصف فاتح (أبيض أفضل) ونصف غامق (أسود أفضل).
    final whiteBg = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08);
    final blackBg = Paint()
      ..color = Colors.grey.withValues(alpha: 0.18);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, mid),
      whiteBg,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, mid, size.width, mid),
      blackBg,
    );

    final zeroPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      zeroPaint,
    );

    // خط التقييم.
    final path = Path();

    path.moveTo(
      _xAt(0, n, size.width),
      _yAt(evalPawns[0], size.height),
    );

    for (var i = 1; i < n; i++) {
      path.lineTo(
        _xAt(i, n, size.width),
        _yAt(evalPawns[i], size.height),
      );
    }

    final linePaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, linePaint);

    // نقاط ملوّنة عند الأخطاء/الفرص الضائعة.
    for (var i = 0; i < qualities.length; i++) {
      final q = qualities[i];

      if (q == MoveQuality.blunder ||
          q == MoveQuality.mistake ||
          q == MoveQuality.miss) {
        final color = moveQualityInfo[q]!.color;

        canvas.drawCircle(
          Offset(
            _xAt(i + 1, n, size.width),
            _yAt(evalPawns[i + 1], size.height),
          ),
          3.5,
          Paint()..color = color,
        );
      }
    }

    // علامات إضافية من List<MoveAnalysisResult>: رائعة / مدهشة
    // بنقطة، واللحظات الحرجة بحلقة ذهبية.
    for (final m in moves) {
      final idx = m.ply + 1;

      if (idx >= n || idx >= evalPawns.length) continue;

      final center = Offset(
        _xAt(idx, n, size.width),
        _yAt(evalPawns[idx], size.height),
      );

      if (m.classification == MoveQuality.brilliant ||
          m.classification == MoveQuality.great) {
        canvas.drawCircle(
          center,
          3.5,
          Paint()..color = moveQualityInfo[m.classification]!.color,
        );
      }

      if (m.isCritical) {
        canvas.drawCircle(
          center,
          6.5,
          Paint()
            ..color = Colors.amber
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }

    // مؤشر الموضع الحالي.
    if (currentIndex >= 0 && currentIndex < n) {
      final x = _xAt(currentIndex, n, size.width);

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.red.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );

      canvas.drawCircle(
        Offset(
          x,
          _yAt(evalPawns[currentIndex], size.height),
        ),
        4.5,
        Paint()..color = Colors.red,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _EvalGraphPainter oldDelegate,
  ) {
    return oldDelegate.currentIndex != currentIndex ||
        oldDelegate.evalPawns != evalPawns ||
        oldDelegate.qualities != qualities ||
        oldDelegate.moves != moves;
  }
}


/// زر الشريط السفلي (أيقونة + عنوان) مع تكرار عند الضغط المطوّل.
class _BarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool repeat;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.repeat = false,
  });

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  Timer? _timer;

  void _start() {
    if (!widget.repeat) return;

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) {
        if (!widget.enabled) {
          _stop();
          return;
        }

        widget.onTap();
      },
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.25);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPressStart: (_) {
        if (!widget.enabled) return;
        widget.onTap();
        _start();
      },
      onLongPressEnd: (_) => _stop(),
      onLongPressCancel: _stop,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 38, color: color),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}


/// رسم التقييم في صفحة الإحصائيات: خلفية داكنة، والمنطقة تحت الخط
/// بيضاء (كلما ارتفع الخط كان الأبيض أفضل)، ونقاط ملوّنة عند
/// الأخطاء والخطأ الفادح والفرص الضائعة.
class _SummaryGraphPainter extends CustomPainter {
  final List<double> evalPawns;
  final List<MoveQuality> qualities;

  const _SummaryGraphPainter({
    required this.evalPawns,
    required this.qualities,
  });

  static const double _cap = 5.0;

  double _x(int i, int n, double w) =>
      n <= 1 ? 0 : (i / (n - 1)) * w;

  double _y(double pawns, double h) {
    final c = pawns.clamp(-_cap, _cap).toDouble();
    final mid = h / 2;
    return mid - (c / _cap) * mid;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = evalPawns.length;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF454341),
    );

    if (n < 2) return;

    final path = Path()..moveTo(0, _y(evalPawns[0], size.height));

    for (var i = 1; i < n; i++) {
      path.lineTo(
        _x(i, n, size.width),
        _y(evalPawns[i], size.height),
      );
    }

    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFF0F0F0),
    );

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      Paint()
        ..color = const Color(0xFF9A9895)
        ..strokeWidth = 1,
    );

    for (var i = 0; i < qualities.length && i + 1 < n; i++) {
      final q = qualities[i];

      if (q == MoveQuality.blunder ||
          q == MoveQuality.mistake ||
          q == MoveQuality.miss) {
        canvas.drawCircle(
          Offset(
            _x(i + 1, n, size.width),
            _y(evalPawns[i + 1], size.height),
          ),
          5,
          Paint()..color = moveQualityInfo[q]!.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SummaryGraphPainter old) {
    return old.evalPawns != evalPawns ||
        old.qualities != qualities;
  }
}

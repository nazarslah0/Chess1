import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';
import 'game_source.dart';
import 'game_source_screen.dart';
import 'pgn_import_screen.dart';

/// شاشة «حلل مباراة»: اختيار مصدر المباراة
/// (Chess.com / Lichess / لصق PGN).
///
/// التصميم مبني على خلفية الملك الذهبي (assets/analyze/) وثلاث بطاقات
/// بأيقوناتها؛ كل المقاسات نسب من عرض/ارتفاع الشاشة فيتطابق الشكل مع
/// التصميم المعتمد على مختلف الأجهزة.
class AnalyzeGameScreen extends StatelessWidget {
  const AnalyzeGameScreen({super.key});

  static const String _bgAsset = 'assets/analyze/analyze_bg.jpg';
  static const String _chessComIcon = 'assets/analyze/icon_chesscom.png';
  static const String _lichessIcon = 'assets/analyze/icon_lichess.png';
  static const String _pgnIcon = 'assets/analyze/icon_pgn.png';

  static const Color _gold = Color(0xFFF1B04C);
  static const Color _page = Color(0xFF070B14);

  /// أبعاد صورة الخلفية (لحساب مقياس التغطية).
  static const double _bgW = 898;
  static const double _bgH = 1751;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _page,
        body: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;

            // ارتفاع الخلفية الفعلي بعد BoxFit.cover (ملتصقة بالأعلى).
            final bgH = math.max(h, w * _bgH / _bgW);

            final cardW = w * 0.2895;
            final gap = w * 0.0245;
            final cardsTop = bgH * 0.549;
            final cardH = cardW * 1.877;

            final contentH = math.max(h, cardsTop + cardH + 24);

            final top = MediaQuery.of(context).padding.top;

            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    _bgAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                SingleChildScrollView(
                  child: SizedBox(
                    height: contentH,
                    width: w,
                    child: Stack(
                      children: [
                        // العنوان.
                        Positioned(
                          top: bgH * 0.414 - w * 0.075,
                          left: 0,
                          right: 0,
                          child: _title(w),
                        ),
                        // العنوان الفرعي.
                        Positioned(
                          top: bgH * 0.475 - w * 0.03,
                          left: 0,
                          right: 0,
                          child: Text(
                            'اختر مصدر المباراة لبدء التحليل',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFA9AEBB),
                              fontSize: w * 0.04,
                            ),
                          ),
                        ),
                        // الفاصل مع التاج.
                        Positioned(
                          top: bgH * 0.512 - w * 0.02,
                          left: 0,
                          right: 0,
                          child: _divider(w),
                        ),
                        // البطاقات (ترتيب RTL: chess.com يمينًا ثم Lichess ثم PGN).
                        Positioned(
                          top: cardsTop,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SourceCard(
                                width: cardW,
                                icon: _chessComIcon,
                                title: 'chess.com',
                                subtitle: 'استيراد من موقع chess.com',
                                accent: const Color(0xFF63C13F),
                                border: const Color(0x8C4FB02E),
                                colors: const [
                                  Color(0xFF12301E),
                                  Color(0xFF0A1A11),
                                ],
                                onTap: () => pushScreen(
                                  context,
                                  GameSourceScreen(source: ChessComSource()),
                                ),
                              ),
                              SizedBox(width: gap),
                              _SourceCard(
                                width: cardW,
                                icon: _lichessIcon,
                                title: 'Lichess',
                                subtitle: 'استيراد من موقع Lichess',
                                accent: const Color(0xFFE5A93B),
                                border: const Color(0x66E0A33A),
                                colors: const [
                                  Color(0xFF1C1D26),
                                  Color(0xFF111218),
                                ],
                                onTap: () => pushScreen(
                                  context,
                                  GameSourceScreen(source: LichessSource()),
                                ),
                              ),
                              SizedBox(width: gap),
                              _SourceCard(
                                width: cardW,
                                icon: _pgnIcon,
                                title: 'لصق PGN',
                                subtitle: 'الصق نص PGN مباشرة',
                                accent: const Color(0xFF3D6BFF),
                                border: const Color(0x803F5BFF),
                                colors: const [
                                  Color(0xFF131C42),
                                  Color(0xFF0A1028),
                                ],
                                onTap: () => pushScreen(
                                  context,
                                  const PgnImportScreen(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // زر الرجوع (أعلى اليمين في RTL).
                PositionedDirectional(
                  start: w * 0.034,
                  top: top + 8,
                  child: _BackButton(size: w * 0.105),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _title(double w) {
    final style = TextStyle(
      fontSize: w * 0.105,
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'حلل ',
            style: style.copyWith(color: Colors.white),
          ),
          TextSpan(
            text: 'مباراة',
            style: style.copyWith(color: _gold),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _divider(double w) {
    Widget line() => Container(
          width: w * 0.116,
          height: 1.5,
          color: _gold.withValues(alpha: 0.9),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        line(),
        SizedBox(width: w * 0.022),
        CustomPaint(
          size: Size(w * 0.05, w * 0.036),
          painter: const _CrownPainter(_gold),
        ),
        SizedBox(width: w * 0.022),
        line(),
      ],
    );
  }
}

// ============================================================
// زر الرجوع
// ============================================================

class _BackButton extends StatelessWidget {
  final double size;

  const _BackButton({required this.size});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB3151821),
      shape: const CircleBorder(
        side: BorderSide(color: Color(0x1FFFFFFF)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: size,
          height: size,
          // السهم يشير لليمين (رجوع في الواجهة RTL) كما في التصميم.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// بطاقة المصدر
// ============================================================

class _SourceCard extends StatelessWidget {
  final double width;
  final String icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color border;
  final List<Color> colors;
  final VoidCallback onTap;

  const _SourceCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.border,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = width * 1.877;
    final radius = BorderRadius.circular(width * 0.15);
    final titleSize = width * 0.115;
    final subSize = width * 0.063;
    final ring = width * 0.277;

    return SizedBox(
      width: width,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          border: Border.all(color: border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 22,
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _WavePainter(accent)),
                  ),
                  Positioned(
                    top: h * 0.082,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        icon,
                        width: width * 0.6,
                        height: width * 0.6,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            SizedBox(width: width * 0.6, height: width * 0.6),
                      ),
                    ),
                  ),
                  Positioned(
                    top: h * 0.504 - titleSize * 0.7,
                    left: 6,
                    right: 6,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: h * 0.607 - subSize * 0.7,
                    left: width * 0.06,
                    right: width * 0.06,
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF9EA3B3),
                        fontSize: subSize,
                        height: 1.45,
                      ),
                    ),
                  ),
                  Positioned(
                    top: h * 0.852 - ring / 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: ring,
                        height: ring,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.25),
                          border: Border.all(color: accent, width: 1.6),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: accent,
                            size: ring * 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// موجتان شفافتان بلون البطاقة في أسفلها.
class _WavePainter extends CustomPainter {
  final Color color;

  const _WavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final back = Path()
      ..moveTo(0, h * 0.885)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.55, h * 0.99, w, h * 0.865)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      back,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.10),
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.8, w, h * 0.2)),
    );

    final crest = Path()
      ..moveTo(0, h * 0.885)
      ..cubicTo(w * 0.30, h * 0.80, w * 0.55, h * 0.99, w, h * 0.865);

    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.55),
    );

    final front = Path()
      ..moveTo(0, h * 0.955)
      ..cubicTo(w * 0.35, h * 0.89, w * 0.62, h * 1.01, w, h * 0.93)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(
      front,
      Paint()..color = color.withValues(alpha: 0.30),
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.color != color;
}

/// تاج ذهبي صغير في الفاصل.
class _CrownPainter extends CustomPainter {
  final Color color;

  const _CrownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h * 0.30)
      ..lineTo(w * 0.25, h * 0.62)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.75, h * 0.62)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.9, h)
      ..lineTo(w * 0.1, h)
      ..close();

    final paint = Paint()..color = color;

    canvas.drawPath(path, paint);

    for (final p in [
      Offset(0, h * 0.28),
      Offset(w * 0.5, h * 0.02),
      Offset(w, h * 0.28),
    ]) {
      canvas.drawCircle(p, w * 0.075, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) => old.color != color;
}

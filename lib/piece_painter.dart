import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'models.dart';

/// رسم احتياطي للقطعة بالرموز (Unicode) عندما لا تتوفر صورة PNG
/// للثيم، أو تفشل صورة الأصول في التحميل.
///
/// [type] حرف القطعة: K Q R B N P
/// [color] حرف اللون: w أو b
class PiecePainter extends CustomPainter {
  final String type;
  final String color;
  final PieceTheme theme;

  const PiecePainter(
    this.type,
    this.color,
    this.theme,
  );

  static const Map<String, String> _glyphs = <String, String>{
    'K': '\u265A',
    'Q': '\u265B',
    'R': '\u265C',
    'B': '\u265D',
    'N': '\u265E',
    'P': '\u265F',
  };

  @override
  void paint(Canvas canvas, Size size) {
    final glyph = _glyphs[type.toUpperCase()];

    if (glyph == null) {
      return;
    }

    final isWhite = color == 'w';

    final fill = isWhite ? theme.whiteFill : theme.blackFill;
    final stroke = isWhite ? theme.whiteStroke : theme.blackStroke;

    final side = size.shortestSide;
    final fontSize = side * 0.86;

    final strokePainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = side * 0.045
            ..strokeJoin = StrokeJoin.round
            ..color = stroke,
        ),
      ),
    )..layout();

    final fillPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontSize: fontSize,
          height: 1,
          color: fill,
        ),
      ),
    )..layout();

    final offset = Offset(
      (size.width - fillPainter.width) / 2,
      (size.height - fillPainter.height) / 2,
    );

    strokePainter.paint(canvas, offset);
    fillPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant PiecePainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.theme != theme;
  }
}

/// صورة القطعة من الأصول: SVG إن كان الثيم SVG، وإلا PNG.
/// عند فشل التحميل يُرسم الرمز الاحتياطي.
Widget pieceAssetImage(
  PieceTheme theme,
  String color,
  String type, {
  double? width,
  double? height,
  bool gapless = true,
}) {
  final fallback = CustomPaint(painter: PiecePainter(type, color, theme));
  final path = theme.assetPath(color, type);

  if (theme.svg) {
    return SvgPicture.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  return Image.asset(
    path,
    width: width,
    height: height,
    fit: BoxFit.contain,
    gaplessPlayback: gapless,
    filterQuality: FilterQuality.medium,
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}

/// تحميل مسبق لقطعة SVG حتى لا تومض عند أول ظهور.
void precachePieceSvg(String path) {
  final loader = SvgAssetLoader(path);

  svg.cache.putIfAbsent(
    loader.cacheKey(null),
    () => loader.loadBytes(null),
  );
}

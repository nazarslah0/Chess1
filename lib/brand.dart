import 'package:flutter/material.dart';

/// اسم التطبيق.
const String kAppName = 'Golden Chess';

/// ألوان الهوية الذهبية.
class GoldColors {
  GoldColors._();

  static const Color light = Color(0xFFFFE9A0);
  static const Color main = Color(0xFFF5C542);
  static const Color deep = Color(0xFFD4A017);
  static const Color dark = Color(0xFF9A6B00);
}

/// تدرّج ذهبي معدني.
const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[
    GoldColors.light,
    GoldColors.main,
    GoldColors.deep,
  ],
);

/// «Golden Chess» حيث كلمة Golden ذهبية وChess بيضاء.
/// الاسم يُكتب دائمًا من اليسار لليمين (اسم علامة تجارية لاتيني).
class GoldenChessTitle extends StatelessWidget {
  final double fontSize;
  final Color chessColor;

  const GoldenChessTitle({
    super.key,
    this.fontSize = 28,
    this.chessColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
      height: 1.1,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => kGoldGradient.createShader(rect),
            blendMode: BlendMode.srcIn,
            child: Text(
              'Golden',
              style: style.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text('Chess', style: style.copyWith(color: chessColor)),
        ],
      ),
    );
  }
}

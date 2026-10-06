import 'package:flutter/material.dart';

/// ثيم التطبيق الموحّد (فاتح/داكن). كل الشاشات تأخذ شكل الأزرار
/// والبطاقات والشريط العلوي من هنا بدل تكرار الأنماط داخل كل شاشة.
class AppTheme {
  AppTheme._();

  static const Color seed = Colors.indigo;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ThemeData(
      colorSchemeSeed: seed,
      useMaterial3: true,
      brightness: brightness,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(centerTitle: true),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: buttonShape),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// نمط شاشات المصادر (Chess.com / Lichess / PGN): داكن بلمسة خضراء،
/// مأخوذ من شاشة Chess.com ومطبَّق بالتساوي على كل المصادر.
class SourceStyle {
  SourceStyle._();

  static const Color bg = Color(0xFF312E2B);
  static const Color panel = Color(0xFF262522);
  static const Color tile = Color(0xFF3A3937);
  static const Color avatar = Color(0xFF3B3937);
  static const Color green = Color(0xFF81B64C);
  static const Color loss = Color(0xFFD85040);
  static const Color draw = Color(0xFFB3B3B3);
  static const Color error = Color(0xFFE57373);

  static InputDecoration input({
    required String label,
    String? hint,
    IconData? icon,
    bool alignLabelWithHint = false,
    Color accent = green,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon:
          icon == null ? null : Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: panel,
      enabledBorder: border(Colors.white12),
      focusedBorder: border(accent, 2),
    );
  }

  static ButtonStyle primaryButton({
    Color color = green,
    Color foreground = Colors.white,
  }) =>
      FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

/// هيكل الشاشة بنمط المصادر (خلفية داكنة وشريط علوي داكن).
class SourceScaffold extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget body;

  const SourceScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SourceStyle.bg,
      appBar: AppBar(
        backgroundColor: SourceStyle.panel,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(child: body),
    );
  }
}

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'home_screen.dart';

/// جذر التطبيق: الثيم الموحّد + اتجاه RTL + الشاشة الرئيسية.
class ChessAnalyzerApp extends StatelessWidget {
  const ChessAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'محلل وضعيات الشطرنج',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // نطبّق RTL على كل الشاشات (بما فيها الشاشات التي
      // تُفتح لاحقًا عبر Navigator.push)، بدل تغليف الشاشة
      // الأولى فقط.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}

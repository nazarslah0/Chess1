import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_theme.dart';
import 'brand.dart';
import 'home_screen.dart';
import 'l10n.dart';

/// جذر التطبيق: الثيم الموحّد + اللغة (تلقائية حسب الجهاز أو يختارها
/// المستخدم) + الشاشة الرئيسية. اتجاه الكتابة (RTL/LTR) يتبع اللغة.
class ChessAnalyzerApp extends StatefulWidget {
  const ChessAnalyzerApp({super.key});

  @override
  State<ChessAnalyzerApp> createState() => _ChessAnalyzerAppState();
}

class _ChessAnalyzerAppState extends State<ChessAnalyzerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// لغة الجهاز تغيّرت أثناء تشغيل التطبيق: نتبعها ما دام الاختيار
  /// «تلقائي».
  @override
  void didChangeLocales(List<Locale>? locales) {
    LocaleController.instance.onSystemLocalesChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          locale: LocaleController.instance.locale,
          supportedLocales: [
            for (final c in kSupportedLanguageCodes) Locale(c),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          home: const HomeScreen(),
        );
      },
    );
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'ads_service.dart';
import 'app_top_bar.dart';
import 'game_analysis_screen.dart';
import 'l10n.dart';
import 'menu_card.dart';

/// نوع تحليل المباراة.
enum AnalysisMode {
  /// تحليل سريع ودقيق لمعظم المباريات (Stockfish على الجهاز).
  quick,

  /// PRO: تقييمات عميقة جاهزة من السحابة (أعمق وأدق وبلا إرهاق للجهاز)،
  /// ويرجع Stockfish المحلي للوضعيات غير المخزنة.
  pro;

  bool get useCloud => this == AnalysisMode.pro;

  /// عمق البحث المحلي لكل وضعية.
  int get depth => 14;
}

/// شاشة اختيار نوع التحليل: تظهر بعد اختيار مباراة (Chess.com / Lichess)
/// أو لصق PGN، ثم تفتح [GameAnalysisScreen] بالنوع المختار.
class AnalysisModeScreen extends StatelessWidget {
  final String pgn;
  final String? whiteLabel;
  final String? blackLabel;
  final String? resultLabel;
  final String sourceLabel;

  /// true إن كان اللاعب المبحوث عنه بالأسود: يظهر في أسفل الرقعة.
  final bool playerIsBlack;

  const AnalysisModeScreen({
    super.key,
    required this.pgn,
    this.whiteLabel,
    this.blackLabel,
    this.resultLabel,
    this.sourceLabel = '',
    this.playerIsBlack = false,
  });

  void _start(BuildContext context, AnalysisMode mode) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameAnalysisScreen(
          pgn: pgn,
          whiteLabel: whiteLabel,
          blackLabel: blackLabel,
          resultLabel: resultLabel,
          sourceLabel: sourceLabel,
          playerIsBlack: playerIsBlack,
          mode: mode,
        ),
      ),
    );
  }

  /// PRO يعتمد على تحليل Lichess السحابي، فلا يعمل بلا إنترنت.
  static Future<bool> _online() async {
    // الويب: قيود CORS تمنع هذا الفحص، فنكتفي بمحاولة التحليل نفسها.
    if (kIsWeb) return true;

    try {
      final r = await http
          .head(Uri.parse('https://lichess.org'))
          .timeout(const Duration(seconds: 6));

      return r.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  /// PRO يُفتح بعد مشاهدة إعلان مكافئ.
  Future<void> _startPro(BuildContext context) async {
    if (!await _online()) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText(
            'Deep Analysis يحتاج اتصالًا بالإنترنت (يعتمد على تحليل '
            'Lichess). تحقق من اتصالك وحاول مجددًا.',
          ),
        ),
      );

      return;
    }

    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deep Analysis (PRO)'),
        content: const TrText(
          'شاهد إعلانًا قصيرًا لفتح التحليل العميق لهذه المباراة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const TrText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const TrText('شاهد الإعلان'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    final earned = await AdsService.instance.showRewarded();

    if (!context.mounted) return;

    if (earned) {
      _start(context, AnalysisMode.pro);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TrText('أكمل مشاهدة الإعلان لفتح التحليل العميق.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF5CB946);
    const amber = Color(0xFFE8A93A);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1E34),
      appBar: const AppTopBar(title: 'تحليل المباراة'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1E34), Color(0xFF142B55)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  const Icon(
                    Icons.show_chart_rounded,
                    size: 64,
                    color: Colors.white38,
                  ),
                  const SizedBox(height: 18),
                  const TrText(
                    'اختر نوع التحليل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 26),
                  AppMenuCard(
                    icon: Icons.bolt_rounded,
                    label: tr('تحليل سريع'),
                    subtitle: tr('سريع ودقيق لمعظم المباريات'),
                    color: green,
                    badge: _Pill(
                      text: tr('موصى به'),
                      background: const Color(0x335CB946),
                      foreground: const Color(0xFF8FDB7E),
                    ),
                    onTap: () => _start(context, AnalysisMode.quick),
                  ),
                  const SizedBox(height: 16),
                  AppMenuCard(
                    icon: Icons.biotech_rounded,
                    label: 'Deep Analysis',
                    subtitle: tr('تحليل أعمق وأدق بتقييمات عميقة'),
                    color: amber,
                    badge: const _Pill(
                      text: 'PRO',
                      background: amber,
                      foreground: Colors.black,
                    ),
                    onTap: () => _startPro(context),
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

class _Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'game_analysis_screen.dart';
import 'menu_card.dart';

/// نوع تحليل المباراة.
enum AnalysisMode {
  /// تحليل سريع ودقيق لمعظم المباريات (الإعدادات الافتراضية).
  quick,

  /// Deep Analysis: أقصى عمق ودقة مع كل أنوية المعالج.
  deep;

  /// عمق بحث Stockfish لكل وضعية.
  int get depth => this == AnalysisMode.deep ? deepDepth : 14;

  /// عمق التحليل العميق (قابل للتعديل: أعلى = أدق وأبطأ).
  static const int deepDepth = 24;

  /// خيارات UCI تُرسل لـ Stockfish قبل التحليل. null = الافتراضي.
  /// Threads = كل أنوية الجهاز (8 أو أكثر إن وُجدت)، وHash أكبر.
  Map<String, String>? engineOptions() {
    if (this == AnalysisMode.quick) return null;

    final cores = _cores();

    return <String, String>{
      'Threads': '$cores',
      'Hash': cores >= 8 ? '512' : '256',
    };
  }

  static int _cores() {
    try {
      final n = Platform.numberOfProcessors;
      return n < 1 ? 1 : n;
    } catch (_) {
      return 4; // الويب أو منصة لا تدعم القراءة
    }
  }
}

/// شاشة اختيار نوع التحليل: تظهر بعد اختيار مباراة (Chess.com / Lichess)
/// أو لصق PGN، ثم تفتح [GameAnalysisScreen] بالنوع المختار.
class AnalysisModeScreen extends StatelessWidget {
  final String pgn;
  final String? whiteLabel;
  final String? blackLabel;
  final String? resultLabel;
  final String sourceLabel;

  const AnalysisModeScreen({
    super.key,
    required this.pgn,
    this.whiteLabel,
    this.blackLabel,
    this.resultLabel,
    this.sourceLabel = '',
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
          mode: mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF5CB946);
    const amber = Color(0xFFE8A93A);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1E34),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E34),
        foregroundColor: Colors.white,
        title: const Text('تحليل المباراة'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
                  const Text(
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
                    label: 'تحليل سريع',
                    subtitle: 'سريع ودقيق لمعظم المباريات',
                    color: green,
                    badge: const _Pill(
                      text: 'موصى به',
                      background: Color(0x335CB946),
                      foreground: Color(0xFF8FDB7E),
                    ),
                    onTap: () => _start(context, AnalysisMode.quick),
                  ),
                  const SizedBox(height: 16),
                  AppMenuCard(
                    icon: Icons.biotech_rounded,
                    label: 'Deep Analysis',
                    subtitle:
                        'أدق عمق ممكن بكل أنوية المعالج، لكنه يستغرق وقتًا أطول',
                    color: amber,
                    badge: const _Pill(
                      text: 'PRO',
                      background: amber,
                      foreground: Colors.black,
                    ),
                    onTap: () => _start(context, AnalysisMode.deep),
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

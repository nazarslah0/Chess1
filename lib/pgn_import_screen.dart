import 'package:flutter/material.dart';

import 'game_analysis_screen.dart';
import 'pgn_utils.dart';
import 'source_style.dart';

/// شاشة استيراد/لصق PGN لتحليله عبر GameAnalysisScreen نفسها
/// المستخدمة لمباريات Chess.com وLichess (مصدر واحد للتحليل)، وبنفس
/// نمط شاشات المصادر.
class PgnImportScreen extends StatefulWidget {
  const PgnImportScreen({super.key});

  @override
  State<PgnImportScreen> createState() => _PgnImportScreenState();
}

class _PgnImportScreenState extends State<PgnImportScreen> {
  final TextEditingController _pgnCtrl = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _pgnCtrl.dispose();
    super.dispose();
  }

  void _analyze() {
    final pgn = _pgnCtrl.text.trim();

    if (pgn.isEmpty) {
      setState(() => _error = 'الصق نص PGN أولًا.');

      return;
    }

    final plies = parsePgnMoves(pgn);

    if (plies == null || plies.isEmpty) {
      setState(() {
        _error = 'تعذر قراءة نقلات هذا الـ PGN. تحقق من صحة الصيغة.';
      });

      return;
    }

    setState(() => _error = null);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameAnalysisScreen(
          pgn: pgn,
          sourceLabel: 'PGN مستورد',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SourceScaffold(
      title: 'استيراد مباراة (PGN)',
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'الصق نص PGN كاملًا (يشمل الرؤوس مثل [White "..."] '
              'إن وُجدت والنقلات).',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _pgnCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                decoration: SourceStyle.input(
                  label: 'PGN',
                  hint: '[White "Nazar"]\n'
                      '[Black "Opponent"]\n'
                      '[Result "1-0"]\n\n'
                      '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 ...',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: SourceStyle.error),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                style: SourceStyle.primaryButton(),
                onPressed: _analyze,
                icon: const Icon(Icons.query_stats_rounded),
                label: const Text('تحليل المباراة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

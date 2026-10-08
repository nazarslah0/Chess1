import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'app_ui.dart';
import 'bot_play_screen.dart';
import 'coach_models.dart';
import 'coach_session.dart';
import 'lichess_puzzles.dart' show PuzzleCategory;
import 'lichess_puzzles_screen.dart';
import 'my_games_screen.dart';
import 'position_analyzer_screen.dart';
import 'puzzles_screen.dart';

/// مدخل مدرب الشطرنج: يشرح كل نقلة بجمل جاهزة مبنية على تحليل
/// Stockfish، بدون إنترنت وبدون أي خدمة خارجية.
class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  State<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> {
  final AppSettings _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();

    CoachSessionStore.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _settingsCard(bool ar) {
    final level = coachLevelFromName(_settings.coachLevelName);
    final lang = coachLangFromName(_settings.coachLangName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ar ? 'مستواك' : 'Your level',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final l in CoachLevel.values)
                  ChoiceChip(
                    label: Text(coachLevelLabel(l, lang)),
                    selected: l == level,
                    onSelected: (_) => _settings.setCoachLevel(l.name),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ar ? 'لغة الشرح' : 'Explanation language',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('العربية'),
                  selected: lang == CoachLang.ar,
                  onSelected: (_) => _settings.setCoachLang('ar'),
                ),
                ChoiceChip(
                  label: const Text('English'),
                  selected: lang == CoachLang.en,
                  onSelected: (_) => _settings.setCoachLang('en'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ar
                  ? 'المدرب يشرح بجمل جاهزة مبنية على تحليل Stockfish — '
                      'يعمل بدون إنترنت.'
                  : 'The coach explains with ready-made sentences built '
                      'from Stockfish analysis — works offline.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightCard(bool ar) {
    final lang = ar ? CoachLang.ar : CoachLang.en;
    final facts = CoachSessionStore.instance.insights(lang);

    if (facts.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ar ? '🎓 ملاحظة المدرب' : '🎓 Coach note',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (final f in facts) Text('• $f'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final ar = _settings.coachLangName != 'en';

        final entries = <_Entry>[
          _Entry(
            Icons.sports_esports_rounded,
            ar ? 'العب مع المدرب' : 'Play with the coach',
            () => const BotPlayScreen(coachMode: true),
          ),
          _Entry(
            Icons.query_stats_rounded,
            ar ? 'حلل مباراتي' : 'Analyze my game',
            () => const AnalyzeGameScreen(),
          ),
          _Entry(
            Icons.grid_view_rounded,
            ar ? 'تحليل وضعية' : 'Position analysis',
            () => const PositionAnalyzerScreen(),
          ),
          _Entry(
            Icons.extension_rounded,
            ar ? 'تدرب على أخطائي' : 'Train on my mistakes',
            () => const PuzzlesScreen(),
          ),
          _Entry(
            Icons.auto_awesome_rounded,
            ar ? 'تدريب Brilliant' : 'Brilliant training',
            () => const LichessPuzzlesScreen(
              category: PuzzleCategory.brilliant,
            ),
          ),
        ];

        return Scaffold(
          appBar: AppBar(title: Text(ar ? 'مدرب الشطرنج' : 'Chess Coach')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _settingsCard(ar),
                const SizedBox(height: 10),
                _insightCard(ar),
                const SizedBox(height: 10),
                for (final e in entries) ...[
                  ListTile(
                    leading: Icon(e.icon),
                    title: Text(e.label),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.06),
                    onTap: () => pushScreen(context, e.builder()),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Entry {
  final IconData icon;
  final String label;
  final Widget Function() builder;

  const _Entry(this.icon, this.label, this.builder);
}

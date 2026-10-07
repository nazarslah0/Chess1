import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'app_ui.dart';
import 'bot_play_screen.dart';
import 'coach_models.dart';
import 'coach_session.dart';
import 'lichess_puzzles.dart' show PuzzleCategory;
import 'lichess_puzzles_screen.dart';
import 'local_coach_service.dart';
import 'my_games_screen.dart';
import 'position_analyzer_screen.dart';
import 'puzzles_screen.dart';

/// AI Chess Coach: مدخل المدرب المحلي (نموذج لغوي يعمل داخل الهاتف).
class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  State<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> {
  final LocalCoachService _coach = LocalCoachService.instance;
  final AppSettings _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();

    CoachSessionStore.instance.load().then((_) {
      if (mounted) setState(() {});
    });

    // Home → فتح المدرب → فحص النموذج → تحميل كسول إن كان مثبّتًا.
    _coach.initialize().then((_) {
      if (_coach.status == CoachStatus.installed &&
          _settings.coachUseModel) {
        _coach.ensureLoaded();
      }
    });
  }

  String _statusText(bool ar) {
    switch (_coach.status) {
      case CoachStatus.unknown:
        return ar ? 'جارٍ فحص نموذج المدرب...' : 'Checking coach model...';
      case CoachStatus.notInstalled:
        return ar
            ? 'نموذج المدرب غير مثبّت — يعمل المدرب بالقوالب'
            : 'Coach model not installed — templates are used';
      case CoachStatus.downloading:
        return ar ? 'تحميل نموذج المدرب...' : 'Downloading coach model...';
      case CoachStatus.installed:
        return ar
            ? 'النموذج مثبّت (يُحمَّل عند الحاجة)'
            : 'Model installed (loaded on demand)';
      case CoachStatus.loading:
        return ar ? 'جارٍ تحميل المدرب...' : 'Loading the coach...';
      case CoachStatus.ready:
        return ar ? '🎓 المدرب جاهز' : '🎓 Coach ready';
      case CoachStatus.error:
        return ar
            ? 'تعذّر تحميل النموذج — يعمل المدرب بالقوالب'
            : 'Could not load the model — templates are used';
    }
  }

  Widget _modelCard(bool ar) {
    final spec = _coach.model.spec;
    final st = _coach.status;

    final sizeGb = (spec.approxBytes / 1e9).toStringAsFixed(1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusText(ar),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ar
                  ? 'النموذج: ${spec.displayName} (${spec.license}). '
                      'يعمل بالكامل داخل الهاتف: بلا API وبلا إرسال بيانات. '
                      'الإنترنت لازم فقط لتنزيل الملف مرة واحدة (~$sizeGb GB).'
                  : 'Model: ${spec.displayName} (${spec.license}). Runs '
                      'fully on-device: no API, no data sent. Internet is '
                      'needed only to download the file once '
                      '(~$sizeGb GB).',
              style: const TextStyle(fontSize: 12),
            ),
            if (st == CoachStatus.downloading) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _coach.downloadProgress),
              const SizedBox(height: 4),
              Text('${(_coach.downloadProgress * 100).round()}%'),
            ],
            if (_coach.lastError != null &&
                (st == CoachStatus.error || st == CoachStatus.notInstalled))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _coach.lastError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (st == CoachStatus.notInstalled || st == CoachStatus.error)
                  FilledButton.icon(
                    onPressed: _coach.download,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      ar ? 'تحميل نموذج المدرب' : 'Download coach model',
                    ),
                  ),
                if (st == CoachStatus.downloading)
                  OutlinedButton(
                    onPressed: _coach.cancelDownload,
                    child: Text(ar ? 'إلغاء' : 'Cancel'),
                  ),
                if (st == CoachStatus.ready)
                  OutlinedButton(
                    onPressed: _coach.unload,
                    child: Text(ar ? 'تحرير الذاكرة' : 'Free memory'),
                  ),
                if (st == CoachStatus.installed ||
                    st == CoachStatus.ready ||
                    st == CoachStatus.error)
                  TextButton(
                    onPressed: _coach.deleteModel,
                    child: Text(ar ? 'حذف النموذج' : 'Delete model'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                ar
                    ? 'استخدام النموذج اللغوي المحلي'
                    : 'Use the local language model',
              ),
              subtitle: Text(
                ar
                    ? 'عند الإيقاف يشرح المدرب بالقوالب فقط'
                    : 'When off, the coach uses templates only',
              ),
              value: _settings.coachUseModel,
              onChanged: _settings.setCoachUseModel,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                ar
                    ? 'شرح كل النقلات بواسطة النموذج'
                    : 'Explain every move with the model',
              ),
              subtitle: Text(
                ar
                    ? 'افتراضيًا: النقلات الصعبة فقط (أسرع وأخف)'
                    : 'Default: hard moves only (faster, lighter)',
              ),
              value: _settings.coachExplainAll,
              onChanged: _settings.setCoachExplainAll,
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
      listenable: Listenable.merge([_coach, _settings]),
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
          appBar: AppBar(title: const Text('AI Chess Coach')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _modelCard(ar),
                const SizedBox(height: 10),
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

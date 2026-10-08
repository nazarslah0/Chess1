import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'app_ui.dart';
import 'bot_play_screen.dart';
import 'coach_models.dart';
import 'coach_remote.dart';
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

  Widget _backendCard(bool ar) {
    final remote = _settings.coachBackend == 'remote';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ar ? 'مصدر الذكاء الاصطناعي' : 'AI source',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    ar ? 'API مجاني (بدون تخزين)' : 'Free API (no storage)',
                  ),
                  selected: remote,
                  onSelected: (_) async {
                    await _settings.setCoachBackend('remote');
                    await _coach.initialize();
                  },
                ),
                ChoiceChip(
                  label: Text(
                    ar ? 'نموذج على الجهاز (~1.1 GB)' : 'On-device (~1.1 GB)',
                  ),
                  selected: !remote,
                  onSelected: (_) async {
                    await _settings.setCoachBackend('local');
                    await _coach.initialize();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              remote
                  ? (ar
                      ? 'يُرسل للمزوّد تحليل Stockfish للنقلة فقط (النقلة، '
                          'التقييم، أفضل نقلة، المرحلة). إن تعذّر الاتصال '
                          'يشرح المدرب بالقوالب.'
                      : 'Only the Stockfish analysis of the move is sent to '
                          'the provider. If it fails, templates are used.')
                  : (ar
                      ? 'يعمل بالكامل داخل الهاتف بلا إنترنت بعد التنزيل.'
                      : 'Runs fully on-device, offline after the download.'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
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
                    ? 'تفعيل الذكاء الاصطناعي (اختياري)'
                    : 'Enable AI explanations (optional)',
              ),
              subtitle: Text(
                ar
                    ? 'يستخدم Stockfish للحساب وGroq/النموذج لشرح النقلة مثل مدرب حقيقي'
                    : 'Stockfish calculates; the selected model explains the move like a real coach',
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
                    ? 'يشرح كل نقلة بعد أن يحسم Stockfish تقييمها'
                    : 'Explain every move after Stockfish determines its result',
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
                _settingsCard(ar),
                const SizedBox(height: 10),
                // الذكاء الاصطناعي اختياري: الافتراضي جمل جاهزة بدون
                // إنترنت ولا تخزين ولا مفتاح.
                if (_settings.coachUseModel) ...[
                  _backendCard(ar),
                  const SizedBox(height: 10),
                  if (_settings.coachBackend == 'remote')
                    _ApiCard(ar: ar)
                  else
                    _modelCard(ar),
                ],
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

/// إعدادات الـAPI المجاني (مزوّد متوافق مع OpenAI).
class _ApiCard extends StatefulWidget {
  final bool ar;

  const _ApiCard({required this.ar});

  @override
  State<_ApiCard> createState() => _ApiCardState();
}

class _ApiCardState extends State<_ApiCard> {
  final AppSettings _s = AppSettings.instance;
  final LocalCoachService _coach = LocalCoachService.instance;

  late final TextEditingController _key =
      TextEditingController(text: _s.coachApiKey);
  late final TextEditingController _model =
      TextEditingController(text: _s.coachApiModel);
  late final TextEditingController _base =
      TextEditingController(text: _s.coachApiBaseUrl);

  bool _testing = false;
  String? _result;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _base.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _s.setCoachApiKey(_key.text);
    await _s.setCoachApiModel(_model.text);
    await _s.setCoachApiBaseUrl(_base.text);
    await _coach.initialize();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });

    await _save();

    final err = await _coach.testConnection();

    if (!mounted) return;

    setState(() {
      _testing = false;
      _result = err == null
          ? (widget.ar ? '✅ الاتصال يعمل' : '✅ Connected')
          : (err == 'notConfigured'
              ? (widget.ar ? 'أدخل مفتاح API أولًا' : 'Enter an API key first')
              : '❌ $err');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.ar;
    final preset = coachApiPreset(_s.coachApiProvider);

    final ready = _coach.status == CoachStatus.ready;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ready
                  ? (ar ? '🎓 المدرب جاهز' : '🎓 Coach ready')
                  : (ar
                      ? 'أدخل مفتاح API لتفعيل المدرب (القوالب تعمل الآن)'
                      : 'Enter an API key to enable the coach '
                          '(templates work meanwhile)'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final p in kCoachApiPresets)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: p.id == preset.id,
                    onSelected: (_) async {
                      // مفتاح مزوّد لا يُرسل لمزوّد آخر.
                      await _s.setCoachApiProvider(p.id);
                      await _s.setCoachApiKey('');

                      _key.clear();
                      _model.clear();
                      _base.clear();

                      await _coach.initialize();

                      if (mounted) setState(() => _result = null);
                    },
                  ),
              ],
            ),
            if (preset.keyUrl.isNotEmpty && preset.requiresKey)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SelectableText(
                  ar
                      ? 'مفتاح مجاني من: ${preset.keyUrl}'
                      : 'Free key at: ${preset.keyUrl}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            if (preset.requiresKey || preset.id == 'custom')
              TextField(
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: ar ? 'مفتاح API' : 'API key',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _model,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: ar ? 'النموذج' : 'Model',
                hintText: preset.defaultModel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (preset.id == 'custom') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _base,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: ar ? 'عنوان API (Base URL)' : 'Base URL',
                  hintText: 'https://.../v1',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _testing ? null : _test,
                  child: Text(
                    _testing
                        ? (ar ? 'جارٍ الاختبار...' : 'Testing...')
                        : (ar ? 'حفظ واختبار الاتصال' : 'Save & test'),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    _key.clear();

                    await _save();

                    if (mounted) setState(() => _result = null);
                  },
                  child: Text(ar ? 'مسح المفتاح' : 'Clear key'),
                ),
              ],
            ),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _result!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              ar
                  ? 'المفتاح يُحفظ على جهازك فقط ويُرسل للمزوّد المختار وحده.'
                  : 'The key is stored on this device only and sent only to '
                      'the chosen provider.',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

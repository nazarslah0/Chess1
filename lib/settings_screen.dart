import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'board_widget.dart';
import 'maia_service.dart';
import 'models.dart';

/// الإعدادات العامة: ثيم الرقعة والقطع (تنطبق على كل رقع التطبيق)،
/// مستوى Maia الافتراضي، واسمك في المباريات.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _s = AppSettings.instance;

  final GameState _preview = GameState();

  late final TextEditingController _nameCtrl =
      TextEditingController(text: _s.playerName);

  List<int> _maiaAvailable = const <int>[];

  @override
  void initState() {
    super.initState();

    _preview.startPosition();

    MaiaService.availableBuckets().then((v) {
      if (mounted) setState(() => _maiaAvailable = v);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _s,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'المظهر (لكل رقع التطبيق)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: BoardWidget(
                      state: _preview,
                      boardTheme: _s.boardTheme,
                      pieceTheme: _s.pieceTheme,
                      onTap: (_) {},
                      interactive: false,
                      showCoordinates: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  decoration:
                      const InputDecoration(labelText: 'ثيم الرقعة'),
                  initialValue: _s.boardThemeIndex,
                  isExpanded: true,
                  items: [
                    for (var i = 0;
                        i < AppSettings.allBoardThemes.length;
                        i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(AppSettings.allBoardThemes[i].name),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _s.setBoardTheme(v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration:
                      const InputDecoration(labelText: 'ثيم القطع'),
                  initialValue: _s.pieceThemeIndex,
                  isExpanded: true,
                  items: [
                    for (var i = 0;
                        i < AppSettings.allPieceThemes.length;
                        i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(AppSettings.allPieceThemes[i].name),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _s.setPieceTheme(v);
                  },
                ),
                const Divider(height: 32),
                _SmartTrainingSettings(settings: _s),
                const Divider(height: 32),
                const Text(
                  'Maia',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _maiaAvailable.isEmpty
                      ? 'لم يتم العثور على أوزان Maia في التطبيق '
                          '(انظر assets/maia/README.txt).'
                      : 'المستوى الافتراضي في تحليل الوضعية واللعب:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final b in MaiaService.buckets)
                      ChoiceChip(
                        label: Text('$b'),
                        selected: _s.maiaBucket == b,
                        onSelected: _maiaAvailable.contains(b)
                            ? (_) => _s.setMaiaBucket(b)
                            : null,
                      ),
                  ],
                ),
                const Divider(height: 32),
                const Text(
                  'اسمك في المباريات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'اسم مستخدمك في Chess.com أو Lichess. يُستخدم لمعرفة أي '
                  'لاعب هو أنت عند استخراج التمارين من أخطائك.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'اسم المستخدم',
                  ),
                  onChanged: _s.setPlayerName,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


class _SmartTrainingSettings extends StatelessWidget {
  final AppSettings settings;

  const _SmartTrainingSettings({required this.settings});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x332E8BFF),
              ),
              child: const Icon(Icons.school_rounded, color: Color(0xFF62A8FF)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('التدريب الذكي أثناء المباراة',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('مدرب تفاعلي يعتمد على Stockfish دون كشف الحل مباشرة',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: settings.smartTraining,
              onChanged: settings.setSmartTraining,
            ),
          ],
        ),
        if (settings.smartTraining) ...[
          const SizedBox(height: 10),
          _switch('Feedback بعد النقلة', settings.trainingFeedback, settings.setTrainingFeedback),
          _switch('إظهار سهم التلميح', settings.showHintArrow, settings.setShowHintArrow),
          _switch('السماح بتجربة أفضل نقلة', settings.allowBestMove, settings.setAllowBestMove),
          _switch('تحليل تلقائي', settings.autoAnalysis, settings.setAutoAnalysis),
          _switch('صوت التدريب', settings.trainingSound, settings.setTrainingSound),
          _switch('اهتزاز خفيف', settings.trainingHaptic, settings.setTrainingHaptic),
          const SizedBox(height: 8),
          Text('تأخير ظهور التغذية الراجعة', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final ms in const [1000, 2000, 3000])
                ChoiceChip(
                  label: Text('${ms ~/ 1000} ثانية'),
                  selected: settings.feedbackDelayMs == ms,
                  onSelected: (_) => settings.setFeedbackDelayMs(ms),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('الحد الأدنى لفقدان التقييم', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (final cp in const [20, 50, 80, 100])
                ChoiceChip(
                  label: Text('$cp cp'),
                  selected: settings.minEvalLossCp == cp,
                  onSelected: (_) => settings.setMinEvalLossCp(cp),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'لن يظهر اقتراح تدريبي بسبب فروقات صغيرة مثل +0.42 مقابل +0.48.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ],
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
    );
  }
}

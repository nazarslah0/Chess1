import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'bot_setup_view.dart' show BotPalette;
import 'coach_models.dart';
import 'training_coach.dart';

/// يظهر/يختفي بحركة بسيطة: Fade + Slide Up (وFade Out عند الإخفاء).
class FloatingSwitcher extends StatelessWidget {
  final Widget? child;

  const FloatingSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (w, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.14),
            end: Offset.zero,
          ).animate(anim),
          child: w,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child ?? const SizedBox.shrink(key: ValueKey<String>('none')),
    );
  }
}

class CoachAction {
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const CoachAction(this.label, this.onTap, {this.primary = false});
}

/// بطاقة المدرب (تظهر فوق الرقعة): عنوان + شرح + أزرار.
class CoachCard extends StatelessWidget {
  final String title;
  final String body;

  /// سطر إضافي (أفضل نقلة / الخط الرئيسي) — يُعرض LTR.
  final String? detail;
  final Color accent;
  final List<CoachAction> actions;

  const CoachCard({
    super.key,
    required this.title,
    required this.body,
    required this.accent,
    required this.actions,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xF2101B35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BotPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: const TextStyle(
                      color: BotPalette.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 6),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        detail!,
                        style: const TextStyle(
                          color: BotPalette.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final a in actions)
                a.primary
                    ? FilledButton(
                        onPressed: a.onTap,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(a.label),
                      )
                    : TextButton(
                        onPressed: a.onTap,
                        style: TextButton.styleFrom(
                          foregroundColor: BotPalette.text,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(a.label),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

/// فقاعة صغيرة (🟢 ممتاز! / جارٍ تحليل النقلة...).
class CoachPill extends StatelessWidget {
  final String text;
  final Color color;
  final bool spinner;

  const CoachPill({
    super.key,
    required this.text,
    required this.color,
    this.spinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xEE101B35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: const TextStyle(
              color: BotPalette.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// «🎓 أداؤك في التدريب» (بعد انتهاء المباراة).
class TrainingSummaryCard extends StatelessWidget {
  final TrainingSummary summary;

  /// ملاحظة المدرب عن المباراة (قالب أو نموذج محلي).
  final CoachExplanation? note;

  const TrainingSummaryCard({super.key, required this.summary, this.note});

  Widget _line(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: BotPalette.muted,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = summary.percentFoundBySelf;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BotPalette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BotPalette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🎓 أداءك في التدريب',
            style: TextStyle(
              color: BotPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _line(
            'النقلات التي وجدتها بنفسك',
            summary.foundBySelf,
            BotPalette.green,
          ),
          _line('احتجت تلميحاً', summary.neededHint, BotPalette.gold),
          _line('شاهدت الحل', summary.sawSolution, BotPalette.blue),
          _line('أخطاء', summary.mistakes, BotPalette.red),
          if (pct != null) ...[
            const SizedBox(height: 8),
            Text(
              'لقد وجدت $pct% من النقلات القوية بنفسك.',
              style: const TextStyle(
                color: BotPalette.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              '🎓 ${note!.summary}\n${note!.lesson}',
              style: const TextStyle(
                color: BotPalette.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// الإعدادات المتقدمة ← التدريب الذكي
// ----------------------------------------------------------------

Future<void> showTrainingAdvancedSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BotPalette.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _TrainingSettingsSheet(),
  );
}

class _TrainingSettingsSheet extends StatelessWidget {
  const _TrainingSettingsSheet();

  Widget _switch(
    String title,
    String subtitle,
    bool value,
    Future<void> Function(bool) onChanged,
  ) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeThumbColor: Colors.white,
      activeTrackColor: BotPalette.green,
      title: Text(
        title,
        style: const TextStyle(
          color: BotPalette.text,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: BotPalette.muted, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _chips(
    String title,
    String subtitle,
    List<int> options,
    int value,
    String Function(int) label,
    Future<void> Function(int) onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BotPalette.text,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: BotPalette.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(label(o)),
                  selected: o == value,
                  onSelected: (_) => onSelect(o),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              shrinkWrap: true,
              children: [
                const Text(
                  '🎓 التدريب الذكي',
                  style: TextStyle(
                    color: BotPalette.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                _switch(
                  'التدريب الذكي أثناء المباراة',
                  'Smart Training — مدرب بجانبك أثناء اللعب',
                  s.smartTraining,
                  s.setSmartTraining,
                ),
                _switch(
                  'ملاحظات التدريب',
                  'Training Feedback — رسائل 🟢 بعد النقلات الجيدة',
                  s.trainingFeedback,
                  s.setTrainingFeedback,
                ),
                _switch(
                  'إظهار سهم التلميح',
                  'Show Hint Arrow',
                  s.trainingHintArrow,
                  s.setTrainingHintArrow,
                ),
                _switch(
                  'السماح بعرض أفضل نقلة',
                  'Allow Best Move — المستوى 3 مع الخط الرئيسي',
                  s.trainingAllowBestMove,
                  s.setTrainingAllowBestMove,
                ),
                _switch(
                  'التحليل التلقائي',
                  'Auto Analysis — بعد كل نقلة. عند الإيقاف: زر «حلّل نقلتي»',
                  s.trainingAutoAnalysis,
                  s.setTrainingAutoAnalysis,
                ),
                _switch(
                  'الصوت',
                  'صوت خفيف عند أفضل نقلة / التلميح / الخطأ',
                  s.trainingSound,
                  s.setTrainingSound,
                ),
                _switch(
                  'الاهتزاز',
                  'Haptic feedback',
                  s.trainingHaptic,
                  s.setTrainingHaptic,
                ),
                _chips(
                  'مدة ظهور الرسائل',
                  'Feedback Delay',
                  AppSettings.trainingDelayOptions,
                  s.trainingFeedbackDelaySec,
                  (v) => v == 3 ? '3 ثوانٍ' : (v == 1 ? '1 ثانية' : '2 ثانية'),
                  s.setTrainingFeedbackDelaySec,
                ),
                _chips(
                  'أقل خسارة تستحق التنبيه',
                  'Minimum Evaluation Loss (الافتراضي 50) — '
                      'الفرق الأصغر لا تظهر له رسالة',
                  AppSettings.trainingMinLossOptions,
                  s.trainingMinLossCp,
                  (v) => '$v cp',
                  s.setTrainingMinLossCp,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

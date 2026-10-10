import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'board_widget.dart';
import 'models.dart';

/// أدوات واجهة مشتركة بين كل الشاشات، حتى لا تُكرَّر الأنماط نفسها
/// (الرقعة، رسائل الحالة، الأزرار، الصفحات الوسطية...) في كل ملف.

/// أقصى عرض مريح للرقعة على الشاشات العريضة.
const double kBoardMaxWidth = 480;

/// ألوان دلالية موحّدة.
class AppColors {
  AppColors._();

  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;

  /// النص الثانوي (يساوي Colors.grey.shade600).
  static const Color muted = Color(0xFF757575);
}

/// رقعة التطبيق: تقرأ ثيم الرقعة والقطع من [AppSettings] وتستمع
/// لتغييرهما، فتنعكس تغييرات الإعدادات على كل الرقع فورًا.
///
/// [maxWidth] يحدّ عرض الرقعة (الافتراضي [kBoardMaxWidth])؛ مرّر
/// `null` إن كانت الشاشة تحدّد حجم الرقعة بنفسها.
class AppBoard extends StatelessWidget {
  final GameState state;
  final void Function(String square)? onTap;
  final Set<String> targets;
  final String? arrowFrom;
  final String? arrowTo;
  final List<BoardArrow> arrows;
  final List<BoardBadge> badges;
  final bool showCoordinates;
  final bool interactive;
  final double? maxWidth;

  const AppBoard({
    super.key,
    required this.state,
    this.onTap,
    this.targets = const {},
    this.arrowFrom,
    this.arrowTo,
    this.arrows = const [],
    this.badges = const [],
    this.showCoordinates = true,
    this.interactive = true,
    this.maxWidth = kBoardMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final board = ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => BoardWidget(
        state: state,
        boardTheme: AppSettings.instance.boardTheme,
        pieceTheme: AppSettings.instance.pieceTheme,
        onTap: onTap ?? (_) {},
        targets: targets,
        arrowFrom: arrowFrom,
        arrowTo: arrowTo,
        arrows: arrows,
        badges: badges,
        showCoordinates: showCoordinates,
        interactive: interactive,
      ),
    );

    final w = maxWidth;

    if (w == null) return board;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: w),
      child: board,
    );
  }
}

/// فتح شاشة جديدة (طريقة تنقّل موحّدة لكل التطبيق).
Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => screen),
  );
}

/// SnackBar موحّد (يزيل أي رسالة سابقة أولًا).
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// صفحة بمحتوى متوسّط وعرض محدود (القوائم الرئيسية).
class CenteredPage extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const CenteredPage({super.key, required this.child, this.maxWidth = 420});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

/// رسالة وسطية لحالات الفراغ والأخطاء.
class CenteredMessage extends StatelessWidget {
  final String text;

  const CenteredMessage(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

/// مؤشر تحميل وسطي.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// صف أزرار موحّد (يلتف على أسطر عند ضيق الشاشة).
class AppActionBar extends StatelessWidget {
  final List<Widget> children;

  const AppActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: children,
    );
  }
}

/// رسالة حالة قصيرة ملوّنة (صحيح/خطأ...). فارغة إن كان [text] null.
class FeedbackText extends StatelessWidget {
  final String? text;
  final Color color;

  const FeedbackText(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = text;

    if (t == null) return const SizedBox.shrink();

    return Text(
      t,
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}

/// بطاقة الحل في شاشات الألغاز.
class SolutionCard extends StatelessWidget {
  final List<Widget> children;

  const SolutionCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// هيكل موحّد لشاشات الألغاز (تمارين مبارياتي + ألغاز Lichess):
/// عنوان، سطر تفاصيل، رقعة، رسالة حالة، بطاقة حل اختيارية، أزرار.
class PuzzleLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget board;
  final String? feedback;
  final Color feedbackColor;
  final Widget? solution;
  final List<Widget> actions;

  /// ترويسة اختيارية تظهر فوق العنوان (مثل مسار المستويات).
  final Widget? header;

  const PuzzleLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.board,
    required this.actions,
    this.feedback,
    this.feedbackColor = Colors.grey,
    this.solution,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    final sol = solution;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (header != null) ...[
            header!,
            const SizedBox(height: 14),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 8),
          board,
          const SizedBox(height: 8),
          FeedbackText(feedback, color: feedbackColor),
          if (sol != null) ...[
            const SizedBox(height: 8),
            sol,
          ],
          const SizedBox(height: 10),
          AppActionBar(children: actions),
        ],
      ),
    );
  }
}

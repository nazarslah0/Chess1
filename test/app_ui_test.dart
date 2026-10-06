import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_analyzer/app_theme.dart';
import 'package:chess_analyzer/app_ui.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  group('AppTheme', () {
    test('الفاتح والداكن Material 3 بنفس البذرة وعنوان وسطي', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.appBarTheme.centerTitle, isTrue);
      expect(dark.appBarTheme.centerTitle, isTrue);
    });
  });

  group('FeedbackText', () {
    testWidgets('يعرض النص بلونه', (tester) async {
      await tester.pumpWidget(
        _wrap(const FeedbackText('صحيح', color: AppColors.success)),
      );

      final text = tester.widget<Text>(find.text('صحيح'));

      expect(text.style?.color, AppColors.success);
    });

    testWidgets('يختفي عندما يكون النص null', (tester) async {
      await tester.pumpWidget(
        _wrap(const FeedbackText(null, color: AppColors.error)),
      );

      expect(find.byType(Text), findsNothing);
    });
  });

  group('PuzzleLayout', () {
    testWidgets('يعرض العنوان والتفاصيل والرقعة والأزرار', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PuzzleLayout(
            title: 'الدور على الأبيض',
            subtitle: 'صعوبة 1500',
            board: const SizedBox(key: Key('board'), height: 40),
            feedback: 'حاول مرة أخرى',
            feedbackColor: AppColors.error,
            actions: [
              OutlinedButton(onPressed: () {}, child: const Text('السابق')),
              FilledButton(onPressed: () {}, child: const Text('التالي')),
            ],
          ),
        ),
      );

      expect(find.text('الدور على الأبيض'), findsOneWidget);
      expect(find.text('صعوبة 1500'), findsOneWidget);
      expect(find.byKey(const Key('board')), findsOneWidget);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      expect(find.text('السابق'), findsOneWidget);
      expect(find.text('التالي'), findsOneWidget);
      expect(find.byType(SolutionCard), findsNothing);
    });

    testWidgets('يعرض بطاقة الحل عند تمريرها', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PuzzleLayout(
            title: 't',
            subtitle: 's',
            board: const SizedBox(height: 40),
            solution: const SolutionCard(children: [Text('الحل: Qh5#')]),
            actions: const [],
          ),
        ),
      );

      expect(find.byType(SolutionCard), findsOneWidget);
      expect(find.text('الحل: Qh5#'), findsOneWidget);
    });
  });

  group('مكوّنات الصفحات', () {
    testWidgets('CenteredMessage يعرض الرسالة', (tester) async {
      await tester.pumpWidget(_wrap(const CenteredMessage('لا توجد بيانات')));

      expect(find.text('لا توجد بيانات'), findsOneWidget);
    });

    testWidgets('LoadingView يعرض مؤشر التحميل', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('showAppSnack يعرض الرسالة', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAppSnack(ctx, 'تم'),
              child: const Text('اضغط'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('اضغط'));
      await tester.pump();

      expect(find.text('تم'), findsOneWidget);
    });

    testWidgets('pushScreen يفتح الشاشة الجديدة', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => pushScreen(
                ctx,
                const Scaffold(body: Text('الشاشة الثانية')),
              ),
              child: const Text('افتح'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      expect(find.text('الشاشة الثانية'), findsOneWidget);
    });
  });
}

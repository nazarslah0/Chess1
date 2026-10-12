import 'package:flutter/material.dart';

import 'app_top_bar.dart';
import 'brand.dart';
import 'l10n.dart';

/// رابط سياسة الخصوصية (استبدله برابط صفحتك المنشورة قبل النشر).
const String kPrivacyPolicyUrl = 'https://example.com/privacy';

/// شاشة «حول التطبيق والتراخيص»: إشعارات المصادر المفتوحة المطلوبة.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);

    const bold = TextStyle(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: const AppTopBar(title: 'حول التطبيق والتراخيص'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GoldenChessTitle(
              fontSize: 24,
              chessColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(tr('محرك Stockfish'), style: bold),
          const SizedBox(height: 4),
          Text(
            tr(
              'يستخدم هذا التطبيق محرك الشطرنج Stockfish (الإصدار 19) المرخّص '
              'برخصة GNU GPL v3، ويعمل كبرنامج منفصل داخل التطبيق دون تعديل. '
              'الكود المصدري للإصدار المستخدم متاح على:',
            ),
          ),
          const SizedBox(height: 4),
          const SelectableText(
            'https://github.com/official-stockfish/Stockfish/tree/sf_19',
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 4),
          SelectableText(
            '${tr('نص الرخصة:')} https://www.gnu.org/licenses/gpl-3.0.html',
            textDirection: TextDirection.ltr,
          ),
          const Divider(height: 32),
          Text(tr('تمارين الشطرنج'), style: bold),
          const SizedBox(height: 4),
          Text(
            tr(
              'تمارين مستخرجة من قاعدة بيانات تمارين Lichess '
              '(database.lichess.org) المتاحة في الملك العام CC0.',
            ),
          ),
          const Divider(height: 32),
          Text(tr('سياسة الخصوصية'), style: bold),
          const SizedBox(height: 4),
          const SelectableText(
            kPrivacyPolicyUrl,
            textDirection: TextDirection.ltr,
          ),
          const Divider(height: 32),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: kAppName,
            ),
            icon: const Icon(Icons.description_outlined),
            label: Text(tr('تراخيص المكتبات')),
          ),
        ],
      ),
    );
  }
}

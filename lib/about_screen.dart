import 'package:flutter/material.dart';

/// رابط سياسة الخصوصية (استبدله برابط صفحتك المنشورة قبل النشر).
const String kPrivacyPolicyUrl = 'https://example.com/privacy';

/// شاشة «حول التطبيق والتراخيص»: إشعارات المصادر المفتوحة المطلوبة.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق والتراخيص')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Golden Chess',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'محرك Stockfish',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'يستخدم هذا التطبيق محرك الشطرنج Stockfish (الإصدار 19) المرخّص '
            'برخصة GNU GPL v3، ويعمل كبرنامج منفصل داخل التطبيق دون تعديل. '
            'الكود المصدري للإصدار المستخدم متاح على:',
          ),
          const SizedBox(height: 4),
          const SelectableText(
            'https://github.com/official-stockfish/Stockfish/tree/sf_19',
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 4),
          const SelectableText(
            'نص الرخصة: https://www.gnu.org/licenses/gpl-3.0.html',
            textDirection: TextDirection.ltr,
          ),
          const Divider(height: 32),
          const Text(
            'تمارين الشطرنج',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'تمارين مستخرجة من قاعدة بيانات تمارين Lichess '
            '(database.lichess.org) المتاحة في الملك العام CC0.',
          ),
          const Divider(height: 32),
          const Text(
            'سياسة الخصوصية',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const SelectableText(
            kPrivacyPolicyUrl,
            textDirection: TextDirection.ltr,
          ),
          const Divider(height: 32),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Golden Chess',
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('تراخيص المكتبات'),
          ),
        ],
      ),
    );
  }
}

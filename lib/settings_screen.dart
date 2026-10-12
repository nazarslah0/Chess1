import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'ads_service.dart';
import 'app_settings.dart';
import 'app_top_bar.dart';
import 'board_widget.dart';
import 'l10n.dart';
import 'models.dart';

/// الإعدادات العامة: ثيم الرقعة والقطع (تنطبق على كل رقع التطبيق)
/// واسمك في المباريات.
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

  @override
  void initState() {
    super.initState();

    _preview.startPosition();
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
      appBar: const AppTopBar(title: 'الإعدادات', isSettings: true),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_s, LocaleController.instance]),
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  tr('اللغة'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.language_rounded),
                    labelText: tr('لغة التطبيق'),
                  ),
                  initialValue: LocaleController.instance.selection,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String>(
                      value: kSystemLanguage,
                      child: Text(tr('تلقائي (لغة الجهاز)')),
                    ),
                    for (final code in kSupportedLanguageCodes)
                      DropdownMenuItem<String>(
                        value: code,
                        child: Text(kLanguageNativeNames[code] ?? code),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) LocaleController.instance.setLanguage(v);
                  },
                ),
                const Divider(height: 32),
                Text(
                  tr('المظهر (لكل رقع التطبيق)'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                      InputDecoration(labelText: tr('ثيم الرقعة')),
                  initialValue: _s.boardThemeIndex,
                  isExpanded: true,
                  items: [
                    for (var i = 0;
                        i < AppSettings.allBoardThemes.length;
                        i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(tr(AppSettings.allBoardThemes[i].name)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _s.setBoardTheme(v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration:
                      InputDecoration(labelText: tr('ثيم القطع')),
                  initialValue: _s.pieceThemeIndex,
                  isExpanded: true,
                  items: [
                    for (var i = 0;
                        i < AppSettings.allPieceThemes.length;
                        i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(tr(AppSettings.allPieceThemes[i].name)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _s.setPieceTheme(v);
                  },
                ),
                const Divider(height: 32),
                Text(
                  tr('اسمك في المباريات'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    'اسم مستخدمك في Chess.com أو Lichess. يُستخدم لمعرفة أي '
                    'لاعب هو أنت عند استخراج التمارين من أخطائك.',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: tr('اسم المستخدم'),
                  ),
                  onChanged: _s.setPlayerName,
                ),
                const Divider(height: 32),
                ValueListenableBuilder<bool>(
                  valueListenable: AdsService.instance.privacyOptionsRequired,
                  builder: (context, required, _) {
                    if (!required) return const SizedBox.shrink();

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(tr('خيارات الخصوصية')),
                      onTap: AdsService.instance.showPrivacyOptions,
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: Text(tr('حول التطبيق والتراخيص')),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

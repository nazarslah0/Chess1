import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_ui.dart';
import 'brand.dart';
import 'l10n.dart';
import 'settings_screen.dart';

/// الاختصار الذي يظهر على زر اللغة لكل لغة مدعومة.
const Map<String, String> kLanguageShortLabels = <String, String>{
  'ar': 'ع',
  'en': 'E',
  'es': 'S',
  'fr': 'F',
};

const Color _kBarBg = Color(0xFF10131C);

/// الشريط العلوي الثابت الموحّد لكل شاشات التطبيق:
///
///  • يسار: زر الإعدادات.
///  • وسط: اسم الشاشة الحالية (أو اسم التطبيق في الشاشة الرئيسية).
///  • يمين: زر تغيير اللغة (حرف مختصر: ع / E / S / F).
///
/// الترتيب ثابت (يسار/يمين فعليًا) في كل اللغات، حتى مع العربية RTL.
///
/// [title] هو النص العربي الأصلي (مفتاح الترجمة)، ويُترجم داخل الشريط
/// فيتغيّر فورًا عند تبديل اللغة. مرّر `null` لإظهار اسم التطبيق.
/// [args] تستبدل العناصر `{name}` داخل العنوان.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Map<String, Object?>? args;

  /// true داخل شاشة الإعدادات نفسها: الزر يظهر مفعّلًا ولا يفتح شاشة ثانية.
  final bool isSettings;

  const AppTopBar({
    super.key,
    this.title,
    this.args,
    this.isSettings = false,
  });

  static const double barHeight = 56;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    // اشتراك في تغيّر اللغة ليُعاد بناء العنوان.
    Localizations.localeOf(context);

    final t = title;

    final Widget center;

    if (t == null) {
      center = const FittedBox(
        fit: BoxFit.scaleDown,
        child: GoldenChessTitle(fontSize: 24),
      );
    } else {
      center = Directionality(
        textDirection:
            LocaleController.instance.isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Text(
          tr(t, args),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: _kBarBg,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: GoldColors.main.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: barHeight,
              // الترتيب فعليًا: إعدادات يسار، لغة يمين، مهما كانت لغة التطبيق.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _SettingsButton(isSettings: isSettings),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Center(child: center),
                        ),
                      ),
                      const _LanguageButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final bool isSettings;

  const _SettingsButton({required this.isSettings});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('الإعدادات'),
      style: IconButton.styleFrom(
        backgroundColor: isSettings
            ? GoldColors.main.withValues(alpha: 0.22)
            : Colors.white12,
        foregroundColor: isSettings ? GoldColors.main : Colors.white,
        fixedSize: const Size(44, 44),
      ),
      icon: const Icon(Icons.settings_rounded),
      onPressed: () {
        if (isSettings) return;

        pushScreen(context, const SettingsScreen());
      },
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        final current = LocaleController.instance.languageCode;

        return PopupMenuButton<String>(
          tooltip: tr('لغة التطبيق'),
          color: const Color(0xFF1A1E2E),
          position: PopupMenuPosition.under,
          onSelected: LocaleController.instance.setLanguage,
          itemBuilder: (context) => [
            for (final code in kSupportedLanguageCodes)
              PopupMenuItem<String>(
                value: code,
                child: Row(
                  children: [
                    _LangBadge(
                      label: kLanguageShortLabels[code] ?? code,
                      selected: code == current,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        kLanguageNativeNames[code] ?? code,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (code == current)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: GoldColors.main,
                      ),
                  ],
                ),
              ),
          ],
          child: _LangBadge(
            label: kLanguageShortLabels[current] ?? current,
            selected: true,
            size: 44,
          ),
        );
      },
    );
  }
}

class _LangBadge extends StatelessWidget {
  final String label;
  final bool selected;
  final double size;

  const _LangBadge({
    required this.label,
    required this.selected,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? GoldColors.main.withValues(alpha: 0.22)
            : Colors.white12,
        border: Border.all(
          color: selected ? GoldColors.main : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? GoldColors.main : Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

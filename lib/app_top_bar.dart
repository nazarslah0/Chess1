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

const Color _kBarTop = Color(0xFF1B2040);
const Color _kBarBottom = Color(0xFF0D1018);

/// الشريط العلوي الثابت الموحّد لكل شاشات التطبيق:
///
///  • يسار: زر الإعدادات.
///  • وسط: اسم الشاشة الحالية بخط ذهبي مزخرف.
///  • يمين: زر تغيير اللغة (حرف مختصر: ع / E / S / F).
///
/// في الشاشة الرئيسية ([home] = true) يكون الشريط أطول ويعرض شعار
/// التطبيق وشعاره النصي. الترتيب ثابت (يسار/يمين فعليًا) في كل اللغات.
///
/// [title] هو النص العربي الأصلي (مفتاح الترجمة)، ويُترجم داخل الشريط
/// فيتغيّر فورًا عند تبديل اللغة. [args] تستبدل العناصر `{name}`.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Map<String, Object?>? args;

  /// true داخل شاشة الإعدادات نفسها: الزر يظهر مفعّلًا ولا يفتح شاشة ثانية.
  final bool isSettings;

  /// الشريط الأكبر الخاص بالشاشة الرئيسية.
  final bool home;

  const AppTopBar({
    super.key,
    this.title,
    this.args,
    this.isSettings = false,
    this.home = false,
  });

  static const double _lineHeight = 2;
  static const double _contentHeight = 58;
  static const double _homeContentHeight = 78;

  @override
  Size get preferredSize => Size.fromHeight(
        (home ? _homeContentHeight : _contentHeight) + _lineHeight,
      );

  @override
  Widget build(BuildContext context) {
    // اشتراك في تغيّر اللغة ليُعاد بناء العنوان.
    Localizations.localeOf(context);

    final rtl = LocaleController.instance.isRtl;
    final textDir = rtl ? TextDirection.rtl : TextDirection.ltr;

    final Widget center;

    if (home) {
      center = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.workspace_premium_rounded,
                color: GoldColors.main,
                size: 24,
              ),
              SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GoldenChessTitle(fontSize: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: textDir,
            child: Text(
              tr('حلّل، تمرّن، والعب بذكاء'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11.5,
                letterSpacing: 0.3,
                height: 1.2,
              ),
            ),
          ),
        ],
      );
    } else if (title == null) {
      center = const FittedBox(
        fit: BoxFit.scaleDown,
        child: GoldenChessTitle(fontSize: 24),
      );
    } else {
      center = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Diamond(),
          const SizedBox(width: 10),
          Flexible(
            child: Directionality(
              textDirection: textDir,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[GoldColors.light, GoldColors.main],
                ).createShader(rect),
                child: Text(
                  tr(title!, args),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const _Diamond(),
        ],
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_kBarTop, _kBarBottom],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeArea(
                bottom: false,
                child: SizedBox(
                  height: home ? _homeContentHeight : _contentHeight,
                  // الترتيب فعليًا: إعدادات يسار، لغة يمين، مهما كانت اللغة.
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Center(
                              child: _SettingsButton(isSettings: isSettings),
                            ),
                          ),
                          Expanded(child: Center(child: center)),
                          const SizedBox(
                            width: 52,
                            child: Center(child: _LanguageButton()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const _GoldLine(height: _lineHeight),
            ],
          ),
        ),
      ),
    );
  }
}

/// خط ذهبي سفلي يتلاشى عند الطرفين.
class _GoldLine extends StatelessWidget {
  final double height;

  const _GoldLine({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0x00F5C542),
            GoldColors.main,
            GoldColors.light,
            GoldColors.main,
            Color(0x00F5C542),
          ],
          stops: <double>[0, 0.25, 0.5, 0.75, 1],
        ),
      ),
    );
  }
}

/// معيّن ذهبي صغير يزيّن اسم الشاشة.
class _Diamond extends StatelessWidget {
  const _Diamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: GoldColors.main,
          borderRadius: BorderRadius.circular(1),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: GoldColors.main.withValues(alpha: 0.6),
              blurRadius: 6,
            ),
          ],
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
            : Colors.white.withValues(alpha: 0.06),
        foregroundColor: GoldColors.main,
        shape: const CircleBorder(),
        side: BorderSide(
          color: GoldColors.main.withValues(alpha: isSettings ? 0.9 : 0.5),
        ),
        fixedSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.settings_rounded, size: 21),
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
          padding: EdgeInsets.zero,
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
            size: 32,
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
            ? GoldColors.main.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: selected
              ? GoldColors.main.withValues(alpha: 0.85)
              : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? GoldColors.main : Colors.white,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

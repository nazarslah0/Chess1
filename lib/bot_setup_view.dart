import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'bot_play_screen.dart' show BotLevel;
import 'models.dart';

/// ألوان واجهة «العب ضد روبوت» (Premium Dark Chess UI).
class BotPalette {
  BotPalette._();

  static const Color bg = Color(0xFF0A1226);
  static const Color bgTop = Color(0xFF0D1A36);
  static const Color card = Color(0xFF101B35);
  static const Color cardBorder = Color(0x26FFFFFF);
  static const Color tile = Color(0xFF14213F);
  static const Color blue = Color(0xFF2F8BFF);
  static const Color gold = Color(0xFFFFB938);
  static const Color goldDeep = Color(0xFFE79A12);
  static const Color text = Color(0xFFEAF0FF);
  static const Color muted = Color(0xFF8C9AB8);
  static const Color green = Color(0xFF34D399);
  static const Color red = Color(0xFFEF5350);
}

/// خيارات «وقت التفكير» (بالثواني؛ 0 = بدون وقت)، بترتيب العرض في
/// التصميم.
const List<int> kBotTimeOptions = <int>[300, 180, 60, 30, 0];

String botTimeLabel(int seconds) {
  switch (seconds) {
    case 0:
      return 'بدون وقت';
    case 30:
      return '30 ث';
    case 60:
      return '1 دقيقة';
    case 180:
      return '3 دقائق';
    case 300:
      return '5 دقائق';
    default:
      return '$seconds ث';
  }
}

/// أيقونة كل مستوى (حسب معرّفه).
IconData botLevelIcon(String id) {
  switch (id) {
    case 'beginner':
      return Icons.crop_square_rounded;
    case 'novice':
      return Icons.bar_chart_rounded;
    case 'intermediate':
      return Icons.signal_cellular_alt_2_bar_rounded;
    case 'advanced':
      return Icons.star_rounded;
    default:
      return Icons.whatshot_rounded;
  }
}

/// شاشة إعداد المباراة ضد الروبوت.
class BotSetupView extends StatelessWidget {
  final List<BotLevel> levels;
  final BotLevel selectedLevel;
  final ValueChanged<BotLevel> onLevel;

  final String colorChoice; // w / b / r
  final ValueChanged<String> onColor;

  final int timeSeconds;
  final ValueChanged<int> onTime;

  final bool starting;
  final String? notice;

  final VoidCallback onStart;
  final VoidCallback onAdvanced;
  final VoidCallback onBack;

  const BotSetupView({
    super.key,
    required this.levels,
    required this.selectedLevel,
    required this.onLevel,
    required this.colorChoice,
    required this.onColor,
    required this.timeSeconds,
    required this.onTime,
    required this.starting,
    required this.notice,
    required this.onStart,
    required this.onAdvanced,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    _Header(onBack: onBack),
                    const SizedBox(height: 10),
                    const _Hero(),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.signal_cellular_alt_rounded,
                      title: 'مستوى الصعوبة',
                      subtitle: 'اختر قوة خصمك',
                      child: _LevelRow(
                        levels: levels,
                        selected: selectedLevel,
                        onTap: onLevel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.person_rounded,
                      title: 'العب بالقطع',
                      subtitle: 'اختر لون قطعك',
                      child: _ColorRow(
                        value: colorChoice,
                        onTap: onColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.schedule_rounded,
                      title: 'وقت التفكير',
                      subtitle: 'الوقت لكل نقلة',
                      child: _TimeRow(
                        value: timeSeconds,
                        onTap: onTime,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.palette_rounded,
                      title: 'شكل الرقعة',
                      subtitle: 'اختر شكل رقعة الشطرنج',
                      child: const _BoardThemeRow(),
                    ),
                    if (notice != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        notice!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: BotPalette.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _BottomBar(
          starting: starting,
          onStart: onStart,
          onAdvanced: onAdvanced,
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------
// الرأس والبطل
// ----------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: BotPalette.card,
              shape: const CircleBorder(
                side: BorderSide(color: BotPalette.cardBorder),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBack,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: BotPalette.text,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.smart_toy_rounded,
                    color: BotPalette.blue,
                    size: 30,
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: BotPalette.text,
                      ),
                      children: [
                        TextSpan(text: 'العب ضد '),
                        TextSpan(
                          text: 'روبوت',
                          style: TextStyle(color: BotPalette.gold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر المستوى والإعدادات وابدأ اللعبة',
                style: TextStyle(color: BotPalette.muted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.45,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/robot/robot_hero.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: BotPalette.card,
                child: Center(
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 72,
                    color: BotPalette.blue,
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x660A1226)],
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xCC101B35),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: BotPalette.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      color: BotPalette.blue,
                      size: 40,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'محرك قوي',
                          style: TextStyle(
                            color: BotPalette.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Stockfish',
                          style: TextStyle(
                            color: BotPalette.muted,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'أداء احترافي وتحليل دقيق',
                          style: TextStyle(
                            color: BotPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------
// بطاقة قسم
// ----------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: BotPalette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BotPalette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BotPalette.blue, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BotPalette.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BotPalette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// بلاطة اختيار عامة: تبرز بإطار أزرق متوهّج عند التحديد.
class _Choice extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final Color? accent;
  final double height;

  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
    this.accent,
    this.height = 74,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? BotPalette.blue;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: height,
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.16) : BotPalette.tile,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? c : BotPalette.cardBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: c.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

// ----------------------------------------------------------------
// المستويات
// ----------------------------------------------------------------

class _LevelRow extends StatelessWidget {
  final List<BotLevel> levels;
  final BotLevel selected;
  final ValueChanged<BotLevel> onTap;

  const _LevelRow({
    required this.levels,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < levels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Choice(
              height: 92,
              accent: levels[i].color,
              selected: levels[i].id == selected.id,
              onTap: () => onTap(levels[i]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    botLevelIcon(levels[i].id),
                    color: levels[i].color,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    levels[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BotPalette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    levels[i].range,
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: BotPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onTap;

  const _ColorRow({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // الترتيب كما في التصميم (من اليمين): عشوائي، أبيض، أسود.
    const items = <(String, String, IconData)>[
      ('r', 'عشوائي', Icons.casino_rounded),
      ('w', 'أبيض', Icons.circle_outlined),
      ('b', 'أسود', Icons.circle),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Choice(
              height: 64,
              selected: value == items[i].$1,
              onTap: () => onTap(items[i].$1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    items[i].$3,
                    color: items[i].$1 == 'b'
                        ? const Color(0xFFB8C2D9)
                        : BotPalette.text,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i].$2,
                    style: const TextStyle(
                      color: BotPalette.text,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  final int value;
  final ValueChanged<int> onTap;

  const _TimeRow({required this.value, required this.onTap});

  IconData _icon(int s) {
    if (s == 0) return Icons.all_inclusive_rounded;
    if (s == 30) return Icons.bolt_rounded;

    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kBotTimeOptions.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Choice(
              height: 64,
              selected: value == kBotTimeOptions[i],
              onTap: () => onTap(kBotTimeOptions[i]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _icon(kBotTimeOptions[i]),
                    color: BotPalette.text,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    botTimeLabel(kBotTimeOptions[i]),
                    maxLines: 1,
                    style: const TextStyle(
                      color: BotPalette.text,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------------
// شكل الرقعة (يضبط ثيم الرقعة العام في AppSettings)
// ----------------------------------------------------------------

class _BoardThemeRow extends StatelessWidget {
  const _BoardThemeRow();

  /// (التسمية، اسم الثيم الموجود في AppSettings.allBoardThemes).
  static const List<(String, String)> _choices = <(String, String)>[
    ('كلاسيك', 'Chess.com Green'),
    ('خشب', 'رقعة حقيقية — خشب'),
    ('أزرق', 'رقعة حقيقية — رخام'),
    ('رمادي', 'رقعة حقيقية — رمادي'),
    ('بنفسجي', 'رقعة حقيقية — بنفسجي'),
    ('داكن', 'داكن'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final all = AppSettings.allBoardThemes;
        final current = AppSettings.instance.boardThemeIndex;

        final items = <(String, int)>[];

        for (final c in _choices) {
          final idx = all.indexWhere((t) => t.name == c.$2);

          if (idx >= 0) items.add((c.$1, idx));
        }

        return SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final idx = items[i].$2;
              final selected = idx == current;

              return GestureDetector(
                onTap: () => AppSettings.instance.setBoardTheme(idx),
                child: SizedBox(
                  width: 62,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: BotPalette.tile,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? BotPalette.blue
                                : BotPalette.cardBorder,
                            width: selected ? 2 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: BotPalette.blue
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _BoardSwatch(theme: all[idx]),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].$1,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected
                              ? BotPalette.text
                              : BotPalette.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BoardSwatch extends StatelessWidget {
  final BoardTheme theme;

  const _BoardSwatch({required this.theme});

  @override
  Widget build(BuildContext context) {
    final asset = theme.imageAsset;

    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _checker(),
      );
    }

    return _checker();
  }

  Widget _checker() {
    return Column(
      children: [
        for (var r = 0; r < 4; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < 4; c++)
                  Expanded(
                    child: ColoredBox(
                      color: (r + c).isEven ? theme.light : theme.dark,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------
// الشريط السفلي: [تحليل أثناء اللعب] [ابدأ اللعبة] [إعدادات متقدمة]
// ----------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  final bool starting;
  final VoidCallback onStart;
  final VoidCallback onAdvanced;

  const _BottomBar({
    required this.starting,
    required this.onStart,
    required this.onAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: BotPalette.bg,
        border: Border(top: BorderSide(color: BotPalette.cardBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
            height: 74,
            child: Row(
              children: [
                // «تحليل أثناء اللعب» = التدريب الذكي أثناء المباراة.
                SizedBox(
                  width: 92,
                  child: ListenableBuilder(
                    listenable: AppSettings.instance,
                    builder: (context, _) {
                      final on = AppSettings.instance.smartTraining;

                      return _MiniTile(
                        onTap: () =>
                            AppSettings.instance.setSmartTraining(!on),
                        icon: Icons.bar_chart_rounded,
                        label: 'تحليل أثناء اللعب',
                        trailing: Switch(
                          value: on,
                          onChanged: AppSettings.instance.setSmartTraining,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          activeThumbColor: Colors.white,
                          activeTrackColor: BotPalette.green,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: starting ? null : onStart,
                    child: Opacity(
                      opacity: starting ? 0.7 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [BotPalette.gold, BotPalette.goldDeep],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  BotPalette.gold.withValues(alpha: 0.4),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Center(
                          child: starting
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Color(0xFF1B1405),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'جارٍ تشغيل المحرك...',
                                      style: TextStyle(
                                        color: Color(0xFF1B1405),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow_rounded,
                                      color: Color(0xFF1B1405),
                                      size: 34,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'ابدأ اللعبة',
                                      style: TextStyle(
                                        color: Color(0xFF1B1405),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 82,
                  child: _MiniTile(
                    onTap: onAdvanced,
                    icon: Icons.settings_rounded,
                    label: 'إعدادات متقدمة',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniTile extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _MiniTile({
    required this.onTap,
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: BotPalette.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BotPalette.cardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BotPalette.blue, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: BotPalette.text,
                fontSize: 10,
                height: 1.15,
              ),
            ),
            if (trailing != null)
              SizedBox(
                height: 24,
                child: FittedBox(child: trailing),
              ),
          ],
        ),
      ),
    );
  }
}

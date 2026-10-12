import 'package:flutter/material.dart';

import 'ads_service.dart';
import 'app_top_bar.dart';
import 'app_ui.dart';
import 'bot_play_screen.dart';
import 'l10n.dart';
import 'lichess_puzzles.dart' show PuzzleCategory;
import 'lichess_puzzles_screen.dart';
import 'menu_card.dart';
import 'my_games_screen.dart';
import 'position_analyzer_screen.dart';
import 'puzzles_screen.dart';

/// الشاشة الرئيسية للتطبيق (القائمة الأساسية).
/// الرقعة والتحليل التفصيلي يبقيان في شاشات فرعية منفصلة،
/// حتى لا تزدحم الشاشة الرئيسية.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // اشتراك في تغيّر اللغة ليُعاد بناء الشاشة عند تبديلها.
    Localizations.localeOf(context);

    final hero = _MenuEntry(
      icon: Icons.query_stats_rounded,
      label: tr('حلل مباراة'),
      color: const Color(0xFF5CB946),
      subtitle: tr('من Chess.com و Lichess'),
      badge: tr('ابدأ من هنا'),
      builder: () => const AnalyzeGameScreen(),
    );

    final position = _MenuEntry(
      icon: Icons.grid_view_rounded,
      label: tr('وضعية خاصة'),
      color: const Color(0xFF4169FF),
      subtitle: tr('أنشئ أي وضعية وحلّلها: Stockfish والكتاب وTablebase'),
      builder: () => const PositionAnalyzerScreen(),
    );

    final myPuzzles = _MenuEntry(
      icon: Icons.extension_rounded,
      label: tr('تمارين من مبارياتك'),
      color: const Color(0xFF9B5CF6),
      subtitle: tr('وضعيات فاتتك فيها نقلة قوية'),
      builder: () => const PuzzlesScreen(),
    );

    final brilliant = _MenuEntry(
      icon: Icons.auto_awesome_rounded,
      label: tr('ألغاز بريليانت'),
      color: const Color(0xFF2EC4C4),
      subtitle: tr('اعثر على التضحية الفائزة'),
      badge: tr('جديد'),
      builder: () => const LichessPuzzlesScreen(
        category: PuzzleCategory.brilliant,
      ),
    );

    final mate = _MenuEntry(
      icon: Icons.flag_rounded,
      label: tr('ألغاز كش مات'),
      color: const Color(0xFFE5534B),
      subtitle: tr('أنهِ المباراة بكش مات'),
      badge: tr('جديد'),
      builder: () => const LichessPuzzlesScreen(
        category: PuzzleCategory.mate,
      ),
    );

    final training = _MenuEntry(
      icon: Icons.psychology_alt_rounded,
      label: tr('ألغاز'),
      color: const Color(0xFFF2A93B),
      subtitle: tr('حل ألغاز بلا حدود وحسّن مستواك'),
      builder: () => const LichessPuzzlesScreen(
        category: PuzzleCategory.training,
      ),
    );

    final bot = _MenuEntry(
      icon: Icons.smart_toy_rounded,
      label: tr('العب ضد روبوت'),
      color: const Color(0xFF4F8DF7),
      subtitle: tr('مبتدئ، متوسط، متقدم، أستاذ، وStockfish'),
      builder: () => const BotPlayScreen(),
    );

    Widget card(_MenuEntry e, {bool compact = false}) => AppMenuCard(
          icon: e.icon,
          label: e.label,
          subtitle: e.subtitle,
          color: e.color,
          compact: compact,
          badge: e.badge == null ? null : MenuBadge(e.badge!),
          onTap: () => pushScreen(context, e.builder()),
        );

    Widget pair(_MenuEntry a, _MenuEntry b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: card(a, compact: true)),
              const SizedBox(width: 12),
              Expanded(child: card(b, compact: true)),
            ],
          ),
        );

    Widget section(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        );

    return Scaffold(
      backgroundColor: _homeBg,
      appBar: const AppTopBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF161B3A), Color(0xFF2A1A44), Color(0xFF0E1118)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        Center(
                          child: Text(
                            tr('حلّل، تمرّن، والعب بذكاء'),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        card(hero),
                        section(tr('تحليل')),
                        pair(position, myPuzzles),
                        section(tr('ألغاز')),
                        pair(brilliant, mate),
                        const SizedBox(height: 12),
                        card(training),
                        section(tr('العب')),
                        card(bot),
                      ],
                    ),
                  ),
                ),
              ),
              // بانر أسفل القائمة فقط، بعيدًا عن الرقعة وأزرار اللعب.
              const AdBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _homeBg = Color(0xFF0E1118);

class _MenuEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String? badge;
  final Widget Function() builder;

  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.badge,
    required this.builder,
  });
}

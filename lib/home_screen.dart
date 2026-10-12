import 'package:flutter/material.dart';

import 'ads_service.dart';
import 'app_ui.dart';
import 'bot_play_screen.dart';
import 'lichess_puzzles.dart' show PuzzleCategory;
import 'lichess_puzzles_screen.dart';
import 'menu_card.dart';
import 'my_games_screen.dart';
import 'position_analyzer_screen.dart';
import 'puzzles_screen.dart';
import 'settings_screen.dart';

/// الشاشة الرئيسية للتطبيق (القائمة الأساسية).
/// الرقعة والتحليل التفصيلي يبقيان في شاشات فرعية منفصلة،
/// حتى لا تزدحم الشاشة الرئيسية.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hero = _MenuEntry(
      icon: Icons.query_stats_rounded,
      label: 'حلل مباراة',
      color: const Color(0xFF5CB946),
      subtitle: 'من Chess.com و Lichess',
      badge: 'ابدأ من هنا',
      builder: () => const AnalyzeGameScreen(),
    );

    final position = _MenuEntry(
      icon: Icons.grid_view_rounded,
      label: 'وضعية خاصة',
      color: const Color(0xFF4169FF),
      subtitle: 'أنشئ أي وضعية وحلّلها: Stockfish والكتاب وTablebase',
      builder: () => const PositionAnalyzerScreen(),
    );

    final myPuzzles = _MenuEntry(
      icon: Icons.extension_rounded,
      label: 'تمارين من مبارياتك',
      color: const Color(0xFF9B5CF6),
      subtitle: 'وضعيات فاتتك فيها نقلة قوية',
      builder: () => const PuzzlesScreen(),
    );

    final brilliant = _MenuEntry(
      icon: Icons.auto_awesome_rounded,
      label: 'ألغاز بريليانت',
      color: const Color(0xFF2EC4C4),
      subtitle: 'اعثر على التضحية الفائزة',
      badge: 'جديد',
      builder: () => const LichessPuzzlesScreen(
        category: PuzzleCategory.brilliant,
      ),
    );

    final mate = _MenuEntry(
      icon: Icons.flag_rounded,
      label: 'ألغاز كش مات',
      color: const Color(0xFFE5534B),
      subtitle: 'أنهِ المباراة بكش مات',
      badge: 'جديد',
      builder: () => const LichessPuzzlesScreen(
        category: PuzzleCategory.mate,
      ),
    );

    final training = _MenuEntry(
      icon: Icons.psychology_alt_rounded,
      label: 'ألغاز',
      color: const Color(0xFFF2A93B),
      subtitle: 'حل ألغاز بلا حدود وحسّن مستواك',
      builder: () => const LichessPuzzlesScreen(
        category: PuzzleCategory.training,
      ),
    );

    final bot = _MenuEntry(
      icon: Icons.smart_toy_rounded,
      label: 'العب ضد روبوت',
      color: const Color(0xFF4F8DF7),
      subtitle: 'مبتدئ، متوسط، متقدم، أستاذ، وStockfish',
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
                        _header(context),
                        const SizedBox(height: 18),
                        card(hero),
                        section('تحليل'),
                        pair(position, myPuzzles),
                        section('ألغاز'),
                        pair(brilliant, mate),
                        const SizedBox(height: 12),
                        card(training),
                        section('العب'),
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

  Widget _header(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFFFF8A9B), Color(0xFF4FD1C5)],
                ).createShader(r),
                child: const Text(
                  'محلل الشطرنج ♟️',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'الإعدادات',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                fixedSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => pushScreen(context, const SettingsScreen()),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'حلّل، تمرّن، والعب بذكاء',
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      ],
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

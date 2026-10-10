import 'package:flutter/material.dart';

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
    final entries = <_MenuEntry>[
      _MenuEntry(
        icon: Icons.grid_view_rounded,
        label: 'وضعية خاصة',
        color: const Color(0xFF4169FF),
        subtitle: 'أنشئ أي وضعية على الرقعة وحلّلها: '
            'Stockfish والكتاب وTablebase',
        builder: () => const PositionAnalyzerScreen(),
      ),
      _MenuEntry(
        icon: Icons.query_stats_rounded,
        label: 'حلل مباراة',
        color: const Color(0xFF5CB946),
        subtitle: 'من Chess.com و Lichess',
        builder: () => const AnalyzeGameScreen(),
      ),
      _MenuEntry(
        icon: Icons.smart_toy_rounded,
        label: 'العب ضد روبوت',
        color: const Color(0xFFE8A93A),
        subtitle: 'مبتدئ، متوسط، متقدم، أستاذ، وStockfish',
        builder: () => const BotPlayScreen(),
      ),
      _MenuEntry(
        icon: Icons.extension_rounded,
        label: 'تمارين من مبارياتك',
        color: const Color(0xFF9B5CF6),
        subtitle: 'وضعيات فاتتك فيها نقلة قوية في مبارياتك',
        builder: () => const PuzzlesScreen(),
      ),
      _MenuEntry(
        icon: Icons.auto_awesome_rounded,
        label: 'ألغاز بريليانت',
        color: const Color(0xFF2EC4C4),
        subtitle: 'اعثر على النقلة البريليانت',
        builder: () => const LichessPuzzlesScreen(
          category: PuzzleCategory.brilliant,
        ),
      ),
      _MenuEntry(
        icon: Icons.flag_rounded,
        label: 'ألغاز جيك ميت',
        color: const Color(0xFFE5534B),
        subtitle: 'أنهِ المباراة بكش مات',
        builder: () => const LichessPuzzlesScreen(
          category: PuzzleCategory.mate,
        ),
      ),
      _MenuEntry(
        icon: Icons.settings_rounded,
        label: 'الإعدادات',
        color: const Color(0xFF8A93A6),
        subtitle: 'ثيم الرقعة والقطع، مستوى Maia، اسمك',
        builder: () => const SettingsScreen(),
      ),
    ];

    return Scaffold(
      backgroundColor: _homeBg,
      appBar: AppBar(
        backgroundColor: _homeBg,
        foregroundColor: Colors.white,
        title: const Text('محلل الشطرنج ♟️'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) => AppMenuCard(
                icon: entries[i].icon,
                label: entries[i].label,
                subtitle: entries[i].subtitle,
                color: entries[i].color,
                onTap: () => pushScreen(context, entries[i].builder()),
              ),
            ),
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
  final Widget Function() builder;

  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.builder,
  });
}

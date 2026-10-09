import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'bot_play_screen.dart';
import 'lichess_puzzles.dart' show PuzzleCategory;
import 'lichess_puzzles_screen.dart';
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
        label: 'تحليل وضعية',
        subtitle: 'أنشئ وضعية أو الصق FEN: Stockfish '
            'والكتاب وTablebase وMaia',
        builder: () => const PositionAnalyzerScreen(),
      ),
      _MenuEntry(
        icon: Icons.query_stats_rounded,
        label: 'حلل مباراة',
        subtitle: 'من Chess.com و Lichess',
        builder: () => const AnalyzeGameScreen(),
      ),
      _MenuEntry(
        icon: Icons.smart_toy_rounded,
        label: 'العب ضد روبوت',
        subtitle: 'مبتدئ، متوسط، متقدم، أستاذ، وStockfish',
        builder: () => const BotPlayScreen(),
      ),
      _MenuEntry(
        icon: Icons.extension_rounded,
        label: 'تمارين من مبارياتك',
        subtitle: 'وضعيات فاتتك فيها نقلة قوية في مبارياتك',
        builder: () => const PuzzlesScreen(),
      ),
      _MenuEntry(
        icon: Icons.auto_awesome_rounded,
        label: 'ألغاز بريليانت',
        subtitle: 'اعثر على النقلة البريليانت',
        builder: () => const LichessPuzzlesScreen(
          category: PuzzleCategory.brilliant,
        ),
      ),
      _MenuEntry(
        icon: Icons.flag_rounded,
        label: 'ألغاز جيك ميت',
        subtitle: 'أنهِ المباراة بكش مات',
        builder: () => const LichessPuzzlesScreen(
          category: PuzzleCategory.mate,
        ),
      ),
      _MenuEntry(
        icon: Icons.settings_rounded,
        label: 'الإعدادات',
        subtitle: 'ثيم الرقعة والقطع، مستوى Maia، اسمك',
        builder: () => const SettingsScreen(),
      ),
    ];

    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('محلل الشطرنج ♟️')),
      body: SafeArea(
        child: CenteredPage(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_4x4_rounded, size: 56, color: primary),
              const SizedBox(height: 8),
              const Text(
                'Chess Analyzer',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 28),
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _MenuButton(
                  icon: entries[i].icon,
                  label: entries[i].label,
                  subtitle: entries[i].subtitle,
                  onTap: () => pushScreen(context, entries[i].builder()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuEntry {
  final IconData icon;
  final String label;
  final String subtitle;
  final Widget Function() builder;

  const _MenuEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.builder,
  });
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}

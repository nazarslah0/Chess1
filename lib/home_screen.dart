import 'package:flutter/material.dart';

import 'main.dart' show PositionAnalyzerScreen;
import 'bot_play_screen.dart';
import 'lichess_puzzles.dart' show PuzzleCategory;
import 'lichess_puzzles_screen.dart';
import 'my_games_screen.dart';
import 'puzzles_screen.dart';
import 'settings_screen.dart';

/// الشاشة الرئيسية الحقيقية للتطبيق (القائمة الأساسية).
/// الرقعة والتحليل التفصيلي يبقيان في شاشات فرعية منفصلة،
/// حتى لا تزدحم الشاشة الرئيسية.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محلل الشطرنج ♟️'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.grid_4x4_rounded,
                    size: 56,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chess Analyzer',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _MenuButton(
                    icon: Icons.grid_view_rounded,
                    label: 'تحليل وضعية',
                    subtitle: 'أنشئ وضعية أو الصق FEN: Stockfish '
                        'والكتاب وTablebase وMaia',
                    onTap: () =>
                        _open(context, const PositionAnalyzerScreen()),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.query_stats_rounded,
                    label: 'حلل مباراة',
                    subtitle: 'من Chess.com و Lichess',
                    onTap: () =>
                        _open(context, const AnalyzeGameScreen()),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.smart_toy_rounded,
                    label: 'العب ضد روبوت',
                    subtitle: 'مبتدئ، متوسط، متقدم، أستاذ، وStockfish',
                    onTap: () => _open(context, const BotPlayScreen()),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.extension_rounded,
                    label: 'تمارين من مبارياتك',
                    subtitle: 'وضعيات فاتتك فيها نقلة قوية في مبارياتك',
                    onTap: () => _open(context, const PuzzlesScreen()),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'ألغاز بريليانت',
                    subtitle: 'اعثر على النقلة البريليانت',
                    onTap: () => _open(
                      context,
                      const LichessPuzzlesScreen(
                        category: PuzzleCategory.brilliant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.flag_rounded,
                    label: 'ألغاز جيك ميت',
                    subtitle: 'أنهِ المباراة بكش مات',
                    onTap: () => _open(
                      context,
                      const LichessPuzzlesScreen(
                        category: PuzzleCategory.mate,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MenuButton(
                    icon: Icons.settings_rounded,
                    label: 'الإعدادات',
                    subtitle: 'ثيم الرقعة والقطع، مستوى Maia، اسمك',
                    onTap: () => _open(context, const SettingsScreen()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    scheme.primary.withValues(alpha: 0.15),
                child: Icon(
                  icon,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
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

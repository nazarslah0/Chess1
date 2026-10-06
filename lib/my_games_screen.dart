import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'game_source.dart';
import 'game_source_screen.dart';
import 'pgn_import_screen.dart';

/// شاشة «حلل مباراة»: اختيار مصدر المباراة
/// (Chess.com / Lichess / لصق PGN).
class AnalyzeGameScreen extends StatelessWidget {
  const AnalyzeGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: CenteredPage(
          maxWidth: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'حلل مباراة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر مصدر المباراة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 28),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SourceTile(
                        logo: const _SourceLogo(
                          asset: 'assets/logos/chesscom.png',
                          fallbackPiece:
                              'assets/pieces/Chesscom/wP.png',
                          color: Color(0xFF7FA650),
                        ),
                        title: 'chess.com',
                        onTap: () => pushScreen(
                          context,
                          GameSourceScreen(source: ChessComSource()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SourceTile(
                        logo: const _SourceLogo(
                          asset: 'assets/logos/lichess.png',
                          fallbackPiece:
                              'assets/pieces/classic/wN.png',
                          color: Color(0xFF3A3A3A),
                        ),
                        title: 'Lichess',
                        onTap: () => pushScreen(
                          context,
                          GameSourceScreen(source: LichessSource()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SourceTile(
                        logo: const _IconLogo(
                          icon: Icons.content_paste_rounded,
                          color: Colors.indigo,
                        ),
                        title: 'لصق PGN',
                        subtitle: 'الصق نص PGN مباشرة',
                        onTap: () => pushScreen(
                          context,
                          const PgnImportScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شعار المصدر: يحاول تحميل ملف الشعار من assets/logos/،
/// وإن لم يوجد يعرض قطعة شطرنج على خلفية بلون المصدر.
class _SourceLogo extends StatelessWidget {
  final String asset;
  final String fallbackPiece;
  final Color color;

  const _SourceLogo({
    required this.asset,
    required this.fallbackPiece,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Image.asset(
          fallbackPiece,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.sports_esports_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _IconLogo extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconLogo({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final Widget logo;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.logo,
    required this.title,
    required this.onTap,
    this.subtitle,
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
            horizontal: 6,
            vertical: 16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              logo,
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

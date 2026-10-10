import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'models.dart';
import 'piece_painter.dart';

/// زر "خيارات الرقعة" الموحّد: يفتح لوحة تغيير ثيم القطع وثيم الرقعة.
/// يوضع في الشريط العلوي لكل صفحة فيها رقعة.
class BoardOptionsButton extends StatelessWidget {
  final Color? color;

  const BoardOptionsButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'خيارات الرقعة',
      icon: Icon(Icons.tune_rounded, color: color),
      onPressed: () => showBoardThemeSheet(context),
    );
  }
}

/// لوحة اختيار ثيم القطع (أولًا) ثم ثيم الرقعة. التغيير فوري ويُحفظ،
/// وينعكس على كل رقع التطبيق.
Future<void> showBoardThemeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF12151F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: const SafeArea(child: _ThemeSheet()),
    ),
  );
}

const Color _kAccent = Color(0xFF6C8CFF);

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'خيارات الرقعة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('ثيم القطع'),
              const SizedBox(height: 8),
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppSettings.allPieceThemes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _Tile(
                    name: AppSettings.allPieceThemes[i].name,
                    selected: i == s.pieceThemeIndex,
                    onTap: () => s.setPieceTheme(i),
                    preview: _PiecePreview(
                      theme: AppSettings.allPieceThemes[i],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle('ثيم الرقعة'),
              const SizedBox(height: 8),
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppSettings.allBoardThemes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _Tile(
                    name: AppSettings.allBoardThemes[i].name,
                    selected: i == s.boardThemeIndex,
                    onTap: () => s.setBoardTheme(i),
                    preview: _BoardPreview(
                      theme: AppSettings.allBoardThemes[i],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  const _Tile({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? _kAccent : Colors.white12,
                  width: selected ? 2.4 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(selected ? 13 : 15),
                child: preview,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PiecePreview extends StatelessWidget {
  final PieceTheme theme;

  const _PiecePreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    final fallback = CustomPaint(painter: PiecePainter('n', 'w', theme));

    return ColoredBox(
      color: const Color(0xFF2A2F3D),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: theme.assetFolder != null
            ? Image.asset(
                theme.assetPath('w', 'n'),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _BoardPreview extends StatelessWidget {
  final BoardTheme theme;

  const _BoardPreview({required this.theme});

  @override
  Widget build(BuildContext context) {
    Widget cell(Color c) => Expanded(child: ColoredBox(color: c));

    final grid = Column(
      children: [
        Expanded(child: Row(children: [cell(theme.light), cell(theme.dark)])),
        Expanded(child: Row(children: [cell(theme.dark), cell(theme.light)])),
      ],
    );

    final asset = theme.imageAsset;

    if (asset == null) return grid;

    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => grid,
    );
  }
}

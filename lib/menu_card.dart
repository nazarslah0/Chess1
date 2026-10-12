import 'package:flutter/material.dart';

/// بطاقة قائمة زجاجية: تدرّج شفاف بلون القسم، إطار ناعم، أيقونة داخل
/// مربع متوهّج، عنوان ووصف في الوسط، وشارة اختيارية في الزاوية.
///
/// [compact] لنسخة أصغر تُرتَّب اثنتين في الصف على الشاشة الرئيسية.
class AppMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  /// مسار صورة اختيارية (asset) تظهر داخل المربع بدل الأيقونة.
  final String? imageAsset;

  /// شارة اختيارية في زاوية البطاقة (مثل "جديد" أو "PRO").
  final Widget? badge;

  final bool compact;

  const AppMenuCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.imageAsset,
    this.badge,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;
    final radius = BorderRadius.circular(compact ? 22 : 26);

    final iconBox = compact ? 52.0 : 64.0;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: c.withValues(alpha: 0.45), width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.withValues(alpha: 0.26),
              c.withValues(alpha: 0.07),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 18,
                  compact ? 18 : 22,
                  compact ? 12 : 18,
                  compact ? 16 : 20,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IconBox(
                        icon: icon,
                        color: c,
                        size: iconBox,
                        imageAsset: imageAsset,
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 15.5 : 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: compact ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: compact ? 11.5 : 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (badge != null)
                PositionedDirectional(
                  top: 10,
                  end: 12,
                  child: badge!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شارة صغيرة (جديد / PRO ...) للزاوية.
class MenuBadge extends StatelessWidget {
  final String text;
  final Color color;

  const MenuBadge(this.text, {super.key, this.color = const Color(0xFFFF5A5F)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String? imageAsset;

  const _IconBox({
    required this.icon,
    required this.color,
    required this.size,
    required this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final dark =
        HSLColor.fromColor(color).withLightness(0.32).toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, dark],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageAsset != null
          ? Image.asset(imageAsset!, fit: BoxFit.cover)
          : Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

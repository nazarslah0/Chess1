import 'package:flutter/material.dart';

/// بطاقة قائمة رئيسية: إطار ملوّن وتدرّج داكن ودائرة أيقونة وزر سهم
/// دائري مع موجة ملوّنة أسفل البطاقة.
class AppMenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  /// مسار صورة اختيارية (asset) تظهر داخل الدائرة بدل الأيقونة.
  final String? imageAsset;

  /// شارة اختيارية بجانب العنوان (مثل "موصى به" أو "PRO").
  final Widget? badge;

  const AppMenuCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.imageAsset,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;
    final radius = BorderRadius.circular(26);

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: c.withValues(alpha: 0.75), width: 1.6),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: 0.20),
              c.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              height: 124,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _WavePainter(c)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _IconCircle(icon: icon, color: c, imageAsset: imageAsset),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (badge != null) ...[
                                    const SizedBox(width: 8),
                                    badge!,
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c, width: 1.8),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: c,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
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

class _IconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? imageAsset;

  const _IconCircle({
    required this.icon,
    required this.color,
    required this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.18),
        border: Border.all(color: c, width: 2.2),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 14),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageAsset != null
          ? Image.asset(imageAsset!, fit: BoxFit.cover)
          : Icon(icon, color: Colors.white, size: 32),
    );
  }
}

/// موجتان شفافتان بلون البطاقة في أسفلها.
class _WavePainter extends CustomPainter {
  final Color color;

  const _WavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    void wave(double base, double amp, double alpha) {
      final path = Path()..moveTo(0, size.height);
      path.lineTo(0, base);
      path.cubicTo(
        size.width * 0.28, base - amp,
        size.width * 0.55, base + amp,
        size.width, base - amp * 0.4,
      );
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    wave(size.height - 22, 10, 0.20);
    wave(size.height - 12, 8, 0.28);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}

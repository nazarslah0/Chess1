import 'dart:async';

import 'package:flutter/material.dart';

import 'brand.dart';

/// شريحة واحدة في بانر الشاشة الرئيسية.
class BannerSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  const BannerSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });
}

/// بانر ذهبي في أعلى الشاشة الرئيسية: شرائح تتبدّل تلقائيًا وتفتح
/// ميزة من ميزات التطبيق عند الضغط عليها.
class HomeBanner extends StatefulWidget {
  final List<BannerSlide> slides;

  const HomeBanner({super.key, required this.slides});

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  final PageController _pc = PageController();

  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pc.hasClients || widget.slides.length < 2) return;

      final next = (_page + 1) % widget.slides.length;

      _pc.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // اشتراك في تغيّر اللغة ليُعاد بناء النصوص.
    Localizations.localeOf(context);

    if (widget.slides.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 138,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF3D2C08), Color(0xFF1A1305)],
        ),
        border: Border.all(
          color: GoldColors.main.withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: GoldColors.main.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // زخرفة: ملك كبير باهت في الخلفية.
          PositionedDirectional(
            end: -14,
            bottom: -22,
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 150,
              color: GoldColors.main.withValues(alpha: 0.07),
            ),
          ),
          PageView.builder(
            controller: _pc,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _SlideView(slide: widget.slides[i]),
          ),
          if (widget.slides.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _page
                            ? GoldColors.main
                            : Colors.white24,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final BannerSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: slide.onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 24),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kGoldGradient,
                boxShadow: [
                  BoxShadow(
                    color: GoldColors.main.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(
                slide.icon,
                size: 32,
                color: const Color(0xFF2A1D00),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slide.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: kGoldGradient,
                    ),
                    child: Text(
                      slide.cta,
                      style: const TextStyle(
                        color: Color(0xFF2A1D00),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

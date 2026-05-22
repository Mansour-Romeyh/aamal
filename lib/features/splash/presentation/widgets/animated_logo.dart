import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';

/// لوجو متحرك – يظهر بتأثير scale + fade + rotation خفيفة
class AnimatedLogo extends StatelessWidget {
  final Duration delay;
  final double size;

  const AnimatedLogo({
    super.key,
    this.delay = Duration.zero,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.handyman_rounded,
          size: size * 0.5,
          color: AppColors.primary,
        ),
      ),
    )
    .animate(delay: delay)
    .scale(
      duration: 1200.ms,
      curve: Curves.elasticOut,
      begin: const Offset(0, 0),
      end: const Offset(1, 1),
    )
    .fadeIn(duration: 600.ms)
    .shimmer(
      delay: 1500.ms,
      duration: 2000.ms,
      color: AppColors.primary.withOpacity(0.2),
    );
  }
}

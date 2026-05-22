import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/app_colors.dart';

/// حلقة نابضة تحيط باللوجو
class PulseRing extends StatelessWidget {
  final double size;
  final Duration delay;

  const PulseRing({
    super.key,
    this.size = 140,
    this.delay = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildRing(1.6, 0.4, delay),
        _buildRing(1.4, 0.6, delay + 500.ms),
        _buildRing(1.2, 0.8, delay + 1000.ms),
      ],
    );
  }

  Widget _buildRing(double scaleEnd, double opacityStart, Duration startDelay) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
    )
    .animate(onPlay: (controller) => controller.repeat())
    .scale(
      duration: 3000.ms,
      begin: const Offset(0.8, 0.8),
      end: Offset(scaleEnd, scaleEnd),
      curve: Curves.easeOut,
    )
    .fadeOut(duration: 3000.ms, curve: Curves.easeOut);
  }
}

/// AnimatedBuilder helper
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}

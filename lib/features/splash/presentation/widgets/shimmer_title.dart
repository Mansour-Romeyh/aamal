import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../app/theme/app_text_styles.dart';

/// عنوان مع تأثير shimmer (لمعان متحرك)
class ShimmerTitle extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final Duration delay;

  const ShimmerTitle({
    super.key,
    required this.text,
    this.textStyle,
    this.delay = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        AppTextStyles.headlineLarge.copyWith(
          color: Colors.white,
          fontSize: 42,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Shimmer.fromColors(
          baseColor: Colors.white,
          highlightColor: Colors.white.withOpacity(0.5),
          period: const Duration(milliseconds: 2000),
          child: Text(
            text,
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    )
    .animate(delay: delay)
    .fadeIn(duration: 800.ms)
    .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic);
  }
}

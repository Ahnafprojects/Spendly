import 'package:flutter/material.dart';

class OnboardingProgressDots extends StatelessWidget {
  final int total;
  final int current;

  const OnboardingProgressDots({
    super.key,
    required this.total,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 7,
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active
                ? const Color(0xFF2E90FA)
                : Colors.white.withValues(alpha: 0.25),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';

class SpendlyBrandMark extends StatelessWidget {
  final double size;
  const SpendlyBrandMark({super.key, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF2E90FA,
            ).withValues(alpha: isDark ? 0.45 : 0.25),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.58,
          height: size * 0.58,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(size * 0.2),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(
            Icons.stacked_line_chart_rounded,
            color: Colors.white,
            size: size * 0.34,
          ),
        ),
      ),
    );
  }
}

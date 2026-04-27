import 'package:flutter/material.dart';

class ScannerOverlay extends StatefulWidget {
  const ScannerOverlay({super.key});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final pulse = 0.6 + (0.4 * _controller.value);
        return CustomPaint(
          painter: _ScannerOverlayPainter(pulse: pulse),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double pulse;

  const _ScannerOverlayPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.56);
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 28),
      width: size.width * 0.82,
      height: size.height * 0.52,
    );

    final fullPath = Path()..addRect(Offset.zero & size);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(22)));
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullPath,
      holePath,
    );
    canvas.drawPath(overlayPath, overlay);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(22)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = const Color(0xFF4F6EF7).withValues(alpha: pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const corner = 26.0;
    final corners = [
      (frameRect.left, frameRect.top, true, true),
      (frameRect.right, frameRect.top, false, true),
      (frameRect.left, frameRect.bottom, true, false),
      (frameRect.right, frameRect.bottom, false, false),
    ];
    for (final c in corners) {
      final x = c.$1;
      final y = c.$2;
      final left = c.$3;
      final top = c.$4;
      final path = Path();
      path.moveTo(x, y + (top ? corner : -corner));
      path.lineTo(x, y);
      path.lineTo(x + (left ? corner : -corner), y);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}

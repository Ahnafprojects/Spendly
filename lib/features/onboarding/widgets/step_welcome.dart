import 'package:flutter/material.dart';
import '../../../shared/widgets/spendly_brand.dart';

class StepWelcome extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepWelcome({super.key, required this.onNext, required this.onSkip});

  @override
  State<StepWelcome> createState() => _StepWelcomeState();
}

class _StepWelcomeState extends State<StepWelcome>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgAnim,
      builder: (_, child) => _buildBg(child!),
      child: _buildContent(),
    );
  }

  Widget _buildBg(Widget child) {
    final t = _bgAnim.value;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.6 + 0.3 * t, -1.0),
          end: Alignment(0.6 - 0.3 * t, 1.0),
          colors: [
            Color.lerp(const Color(0xFF060C1E), const Color(0xFF09152F), t)!,
            Color.lerp(const Color(0xFF0D1B38), const Color(0xFF050A18), t)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Top-right glow blob
          Positioned(
            top: -60 + 25 * t,
            right: -70,
            child: _blob(
              280,
              const Color(0xFF2E90FA),
              0.12 + 0.06 * t,
            ),
          ),
          // Bottom-left glow blob
          Positioned(
            bottom: 60 + 30 * t,
            left: -80,
            child: _blob(
              320,
              const Color(0xFF00C2A8),
              0.09 + 0.05 * t,
            ),
          ),
          // Center tiny blob
          Positioned(
            top: 180 - 15 * t,
            left: 40,
            child: _blob(
              120,
              const Color(0xFF7C3AED),
              0.07 + 0.03 * t,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(double size, Color color, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SafeArea(
      child: Column(
        children: [
          // Skip button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 20),
              child: TextButton(
                onPressed: widget.onSkip,
                child: Text(
                  'Lewati',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(flex: 2),

          // Logo + brand
          const SpendlyBrandMark(size: 90),
          const SizedBox(height: 24),
          const Text(
            'Spendly',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kendali penuh atas keuanganmu',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              'Setup hanya 2 menit',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),

          const Spacer(flex: 3),

          // CTA button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _GradientButton(
              label: 'Mulai Sekarang',
              onTap: widget.onNext,
            ),
          ),

          const SizedBox(height: 20),
          Text(
            'Gratis selamanya',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E90FA).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

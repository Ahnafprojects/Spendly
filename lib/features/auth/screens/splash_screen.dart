import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/widgets/spendly_brand.dart';
import '../auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  double _opacity = 0.0;
  double _scale = 0.9;

  @override
  void initState() {
    super.initState();
    _startAnimationAndNavigate();
  }

  Future<void> _startAnimationAndNavigate() async {
    // Memulai animasi fade-in setelah sedikit delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _opacity = 1.0;
        _scale = 1.0;
      });
    }

    // Menunggu animasi selesai
    await Future.delayed(const Duration(seconds: 2));

    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final authService = ref.read(authServiceProvider);
    final prefs = await SharedPreferences.getInstance();
    final session = authService.currentSession;
    if (!mounted) return;

    if (session != null) {
      // Logged-in user: check if they need to complete onboarding.
      // onboarding_completed == false means new user explicitly sent to onboarding.
      // null means existing user (before this feature) — go straight to dashboard.
      final onboardingVal = prefs.getBool('onboarding_completed');
      if (onboardingVal == false) {
        context.goNamed('onboarding');
      } else {
        context.goNamed('dashboard');
      }
    } else {
      context.goNamed('auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF060A15) : const Color(0xFFF4F8FF);
    final title = isDark ? Colors.white : const Color(0xFF10213D);
    final subtitle = isDark ? Colors.white70 : const Color(0xFF4F5D78);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(seconds: 1),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            scale: _scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: -90,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFF2E90FA,
                      ).withValues(alpha: isDark ? 0.16 : 0.1),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpendlyBrandMark(size: 92),
                    const SizedBox(height: 18),
                    Text(
                      'Spendly',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: title,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track smarter, spend better',
                      style: TextStyle(
                        color: subtitle,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

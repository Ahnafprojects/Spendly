import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_notifier.dart';
import '../widgets/onboarding_progress_dots.dart';
import '../widgets/step_budget.dart';
import '../widgets/step_complete.dart';
import '../widgets/step_currency.dart';
import '../widgets/step_first_account.dart';
import '../widgets/step_name_avatar.dart';
import '../widgets/step_welcome.dart';

const _kTotalSteps = 6;
const _kDarkBg = Color(0xFF060C1E);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageCtrl;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_isAnimating) return;
    _isAnimating = true;
    _pageCtrl
        .animateToPage(
          page,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        )
        .then((_) => _isAnimating = false);
  }

  void _next() {
    final current = ref.read(onboardingProvider).currentStep;
    if (current < _kTotalSteps - 1) {
      ref.read(onboardingProvider.notifier).nextStep();
      _goToPage(current + 1);
    }
  }

  void _prev() {
    final current = ref.read(onboardingProvider).currentStep;
    if (current > 0) {
      ref.read(onboardingProvider.notifier).prevStep();
      _goToPage(current - 1);
    }
  }

  void _skip() {
    // Skip to auth without completing setup
    context.goNamed('auth');
  }

  void _done() {
    context.goNamed('dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(onboardingProvider.select((s) => s.currentStep));
    final isSaving = ref.watch(onboardingProvider.select((s) => s.isSaving));

    return Scaffold(
      backgroundColor: _kDarkBg,
      body: Stack(
        children: [
          // Page content
          PageView(
            controller: _pageCtrl,
            physics: isSaving
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            onPageChanged: (page) {
              final current = ref.read(onboardingProvider).currentStep;
              if (current != page) {
                ref.read(onboardingProvider.notifier).goToStep(page);
              }
            },
            children: [
              StepWelcome(onNext: _next, onSkip: _skip),
              _StepShell(child: StepNameAvatar(onNext: _next)),
              _StepShell(child: StepCurrency(onNext: _next)),
              _StepShell(child: StepFirstAccount(onNext: _next)),
              _StepShell(child: StepBudget(onNext: _next)),
              _StepShell(child: StepComplete(onDone: _done)),
            ],
          ),

          // Navigation header (hidden on step 0 and step 5)
          if (step > 0 && step < _kTotalSteps - 1)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _prev,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white70,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Back button on step 5 (complete), no skip
          if (step == _kTotalSteps - 1 && !isSaving)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _prev,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.white70,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Progress dots (hidden on step 0)
          if (step > 0)
            Positioned(
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              left: 0,
              right: 0,
              child: Center(
                child: OnboardingProgressDots(
                  total: _kTotalSteps - 1, // exclude welcome
                  current: step - 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Wraps non-welcome steps in a SafeArea with consistent top padding
class _StepShell extends StatelessWidget {
  final Widget child;

  const _StepShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 56), // space for back button
        child: child,
      ),
    );
  }
}

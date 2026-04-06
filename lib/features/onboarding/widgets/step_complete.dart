import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/app_notice.dart';
import '../onboarding_notifier.dart';
import '../onboarding_service.dart';

const _kTypeIcons = {
  'cash': Icons.payments_rounded,
  'bank': Icons.account_balance_rounded,
  'ewallet': Icons.phone_android_rounded,
};

const _kTypeColors = {
  'cash': Color(0xFF00C2A8),
  'bank': Color(0xFF2E90FA),
  'ewallet': Color(0xFF8B5CF6),
};

class StepComplete extends ConsumerStatefulWidget {
  final VoidCallback onDone;

  const StepComplete({super.key, required this.onDone});

  @override
  ConsumerState<StepComplete> createState() => _StepCompleteState();
}

class _StepCompleteState extends ConsumerState<StepComplete>
    with TickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _cardCtrl;
  late Animation<double> _cardAnim;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(
      duration: const Duration(seconds: 4),
    );
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardAnim = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutBack);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _confetti.play();
        _cardCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    ref.read(onboardingProvider.notifier).setSaving(true);

    try {
      final data = ref.read(onboardingProvider);
      await OnboardingService.completeOnboarding(data);
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) {
        AppNotice.error(context, 'Gagal menyimpan: $e');
        setState(() => _saving = false);
        ref.read(onboardingProvider.notifier).setSaving(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final firstName = state.name.trim().split(' ').first;
    final typeColor =
        _kTypeColors[state.accountType] ?? const Color(0xFF2E90FA);
    final typeIcon =
        _kTypeIcons[state.accountType] ?? Icons.account_balance_wallet_rounded;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkmark icon
              ScaleTransition(
                scale: _cardAnim,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E90FA).withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              FadeTransition(
                opacity: _cardAnim,
                child: Column(
                  children: [
                    Text(
                      'Semua siap, $firstName!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Perjalanan finansialmu dimulai sekarang',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Summary card
              ScaleTransition(
                scale: _cardAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Setup',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Name row
                      _summaryRow(
                        icon: Icons.person_rounded,
                        color: const Color(0xFF2E90FA),
                        label: 'Nama',
                        value: state.name.trim(),
                      ),
                      const SizedBox(height: 12),

                      // Account row
                      _summaryRow(
                        icon: typeIcon,
                        color: typeColor,
                        label: 'Dompet',
                        value: state.accountName.trim(),
                      ),
                      const SizedBox(height: 12),

                      // Currency row
                      _summaryRow(
                        icon: Icons.language_rounded,
                        color: const Color(0xFF00C2A8),
                        label: 'Mata Uang',
                        value: state.currency,
                      ),

                      // Budget row
                      if (!state.skipBudget) ...[
                        const SizedBox(height: 12),
                        _summaryRow(
                          icon: Icons.pie_chart_outline_rounded,
                          color: const Color(0xFFFFB020),
                          label: 'Budget Bulanan',
                          value: fmt.format(state.monthlyBudget),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // CTA button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E90FA).withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Masuk ke Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            maxBlastForce: 7,
            minBlastForce: 3,
            emissionFrequency: 0.06,
            numberOfParticles: 18,
            gravity: 0.08,
            shouldLoop: false,
            colors: const [
              Color(0xFF2E90FA),
              Color(0xFF00C2A8),
              Color(0xFFFFB020),
              Colors.white,
              Color(0xFF8B5CF6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

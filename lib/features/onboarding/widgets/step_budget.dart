import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../onboarding_notifier.dart';

const _kMin = 500000.0;
const _kMax = 50000000.0;
const _kStep = 500000.0;
const _kDivisions = ((_kMax - _kMin) / _kStep);

const _kQuickSelect = [
  (label: 'Hemat', value: 1500000.0, color: Color(0xFF00C2A8)),
  (label: 'Normal', value: 3000000.0, color: Color(0xFF2E90FA)),
  (label: 'Bebas', value: 7000000.0, color: Color(0xFFFF5A6E)),
];

class StepBudget extends ConsumerWidget {
  final VoidCallback onNext;

  const StepBudget({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final fmt = NumberFormat.compactCurrency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final fullFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final perDay = (state.monthlyBudget / 30).roundToDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Target pengeluaran\nbulananmu?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kamu bisa ubah kapan saja di pengaturan',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Quick select chips
          Row(
            children: _kQuickSelect.map((q) {
              final selected =
                  !state.skipBudget && state.monthlyBudget == q.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: q.label != 'Bebas' ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      notifier.setSkipBudget(false);
                      notifier.setMonthlyBudget(q.value);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: selected
                            ? q.color.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? q.color
                              : Colors.white.withValues(alpha: 0.1),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            q.label,
                            style: TextStyle(
                              color: selected
                                  ? q.color
                                  : Colors.white.withValues(alpha: 0.55),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fmt.format(q.value),
                            style: TextStyle(
                              color: selected
                                  ? q.color.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.3),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Budget amount display
          AnimatedOpacity(
            opacity: state.skipBudget ? 0.3 : 1.0,
            duration: const Duration(milliseconds: 250),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        fullFmt.format(state.monthlyBudget),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sekitar ${fullFmt.format(perDay)} per hari',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF2E90FA),
                    inactiveTrackColor:
                        Colors.white.withValues(alpha: 0.12),
                    thumbColor: Colors.white,
                    overlayColor:
                        const Color(0xFF2E90FA).withValues(alpha: 0.18),
                    trackHeight: 5,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 22,
                    ),
                  ),
                  child: Slider(
                    value: state.monthlyBudget.clamp(_kMin, _kMax),
                    min: _kMin,
                    max: _kMax,
                    divisions: _kDivisions.toInt(),
                    onChanged: state.skipBudget
                        ? null
                        : (v) {
                            final snapped =
                                (v / _kStep).round() * _kStep;
                            notifier.setMonthlyBudget(snapped);
                          },
                  ),
                ),

                // Range labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rp 500 rb',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Rp 50 jt',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Skip toggle
          GestureDetector(
            onTap: () => notifier.setSkipBudget(!state.skipBudget),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: state.skipBudget
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: state.skipBudget
                          ? const Color(0xFF2E90FA)
                          : Colors.transparent,
                      border: Border.all(
                        color: state.skipBudget
                            ? const Color(0xFF2E90FA)
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: state.skipBudget
                        ? const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Lewati dulu, set budget nanti',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
                ),
              ),
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Lanjut',
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
    );
  }
}

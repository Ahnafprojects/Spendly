import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/currency_settings.dart';
import '../onboarding_notifier.dart';

const _kTopCurrencies = ['IDR', 'USD', 'SGD', 'MYR', 'JPY', 'EUR'];

const _kCurrencyFlags = <String, String>{
  'IDR': 'ID',
  'USD': 'US',
  'AUD': 'AU',
  'CAD': 'CA',
  'GBP': 'GB',
  'EUR': 'EU',
  'SGD': 'SG',
  'MYR': 'MY',
  'THB': 'TH',
  'CNY': 'CN',
  'JPY': 'JP',
  'KRW': 'KR',
  'INR': 'IN',
  'AED': 'AE',
};

class StepCurrency extends ConsumerWidget {
  final VoidCallback onNext;

  const StepCurrency({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final topOptions = CurrencySettings.options
        .where((o) => _kTopCurrencies.contains(o.code))
        .toList()
      ..sort((a, b) =>
          _kTopCurrencies.indexOf(a.code)
              .compareTo(_kTopCurrencies.indexOf(b.code)));

    final otherOptions = CurrencySettings.options
        .where((o) => !_kTopCurrencies.contains(o.code))
        .toList();

    final bottomInset =
        MediaQuery.of(context).viewPadding.bottom + 56; // progress dots

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — fixed, not scrollable
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mata uang utamamu?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih mata uang untuk tampilan saldo dan transaksi',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),

        // Scrollable currency list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: topOptions.length,
                  itemBuilder: (_, i) {
                    final opt = topOptions[i];
                    return _CurrencyCard(
                      option: opt,
                      flag: _kCurrencyFlags[opt.code] ?? '',
                      selected: state.currency == opt.code,
                      onTap: () => notifier.setCurrency(opt.code),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Lainnya',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Other currencies list
                ...otherOptions.map((opt) {
                  final selected = state.currency == opt.code;
                  return _CurrencyListTile(
                    option: opt,
                    flag: _kCurrencyFlags[opt.code] ?? '',
                    selected: selected,
                    onTap: () => notifier.setCurrency(opt.code),
                  );
                }),
              ],
            ),
          ),
        ),

        // Continue button — pinned at bottom
        Padding(
          padding: EdgeInsets.fromLTRB(28, 12, 28, bottomInset),
          child: SizedBox(
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
        ),
      ],
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final CurrencyOption option;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyCard({
    required this.option,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E90FA).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF2E90FA)
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E90FA).withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              flag.isNotEmpty ? _flagEmoji(flag) : option.symbol.trim(),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text(
              option.code,
              style: TextStyle(
                color: selected ? const Color(0xFF2E90FA) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Icon(
              Icons.check_circle_rounded,
              color: selected
                  ? const Color(0xFF2E90FA)
                  : Colors.transparent,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  String _flagEmoji(String countryCode) {
    if (countryCode == 'EU') return option.symbol.trim();
    const base = 0x1F1E6;
    final codeUnits = countryCode.codeUnits;
    if (codeUnits.length != 2) return option.symbol.trim();
    return String.fromCharCode(base + codeUnits[0] - 65) +
        String.fromCharCode(base + codeUnits[1] - 65);
  }
}

class _CurrencyListTile extends StatelessWidget {
  final CurrencyOption option;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyListTile({
    required this.option,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  String _flagEmoji(String countryCode) {
    if (countryCode.isEmpty || countryCode == 'EU') return option.symbol.trim();
    const base = 0x1F1E6;
    final codeUnits = countryCode.codeUnits;
    if (codeUnits.length != 2) return option.symbol.trim();
    return String.fromCharCode(base + codeUnits[0] - 65) +
        String.fromCharCode(base + codeUnits[1] - 65);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2E90FA).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF2E90FA).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Text(_flagEmoji(flag), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.code,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF2E90FA)
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    option.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF2E90FA),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

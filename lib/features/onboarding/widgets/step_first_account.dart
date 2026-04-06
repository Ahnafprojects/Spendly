import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/currency_settings.dart';
import '../onboarding_notifier.dart';

const _kAccountTypes = [
  (key: 'cash', label: 'Tunai', icon: Icons.payments_rounded),
  (key: 'bank', label: 'Bank', icon: Icons.account_balance_rounded),
  (key: 'ewallet', label: 'E-Wallet', icon: Icons.phone_android_rounded),
];

const _kTypeColors = {
  'cash': Color(0xFF00C2A8),
  'bank': Color(0xFF2E90FA),
  'ewallet': Color(0xFF8B5CF6),
};

class StepFirstAccount extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const StepFirstAccount({super.key, required this.onNext});

  @override
  ConsumerState<StepFirstAccount> createState() => _StepFirstAccountState();
}

class _StepFirstAccountState extends ConsumerState<StepFirstAccount> {
  late TextEditingController _nameCtrl;
  late TextEditingController _balanceCtrl;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingProvider);
    _nameCtrl = TextEditingController(text: state.accountName);
    _balanceCtrl = TextEditingController(
      text: state.initialBalance > 0
          ? CurrencySettings.formatInputFromIdr(state.initialBalance)
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      ref.read(onboardingProvider).accountName.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          28,
          20,
          28,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tambahkan dompet\npertamamu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kamu bisa tambah lebih banyak akun nanti',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Account name
            _label('Nama Dompet'),
            const SizedBox(height: 8),
            _DarkTextField(
              controller: _nameCtrl,
              hintText: 'cth. Dompet Utama',
              onChanged: notifier.setAccountName,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 20),

            // Account type
            _label('Jenis Akun'),
            const SizedBox(height: 10),
            Row(
              children: _kAccountTypes.map((t) {
                final selected = state.accountType == t.key;
                final color =
                    _kTypeColors[t.key] ?? const Color(0xFF2E90FA);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: t.key != 'ewallet' ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => notifier.setAccountType(t.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? color
                                : Colors.white.withValues(alpha: 0.1),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              t.icon,
                              color: selected
                                  ? color
                                  : Colors.white.withValues(alpha: 0.4),
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t.label,
                              style: TextStyle(
                                color: selected
                                    ? color
                                    : Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 20),

            // Initial balance
            _label('Saldo saat ini (opsional)'),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final currOpt =
                    CurrencySettings.byCode(state.currency) ??
                    CurrencySettings.options.first;
                return _DarkTextField(
                  controller: _balanceCtrl,
                  hintText: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandsFormatter(currOpt.locale)],
                  prefixText: '${currOpt.symbol.trim()} ',
                  onChanged: (v) {
                    final idr = CurrencySettings.parseInputToIdr(v);
                    notifier.setInitialBalance(idr);
                  },
                );
              },
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 6),
                Text(
                  'Saldo akan disesuaikan setelah transaksi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: AnimatedOpacity(
                opacity: _canContinue ? 1.0 : 0.45,
                duration: const Duration(milliseconds: 200),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E90FA), Color(0xFF00C2A8)],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _canContinue ? widget.onNext : null,
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
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.65),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ThousandsFormatter extends TextInputFormatter {
  final String locale;

  _ThousandsFormatter(this.locale);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final number = int.tryParse(digits) ?? 0;
    final formatted = NumberFormat.decimalPattern(locale).format(number);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final TextCapitalization textCapitalization;

  const _DarkTextField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 16,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF2E90FA),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

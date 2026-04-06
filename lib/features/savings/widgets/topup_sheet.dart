import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/currency_settings.dart';
import '../../account/account_notifier.dart';
import '../../account/account_repository.dart';
import '../savings_goal_model.dart';

class TopUpSheetResult {
  final double amount;
  final String accountId;
  final String? note;

  const TopUpSheetResult({
    required this.amount,
    required this.accountId,
    required this.note,
  });
}

class TopUpSheet extends ConsumerStatefulWidget {
  final SavingsGoalModel goal;
  final bool isWithdraw;

  const TopUpSheet({super.key, required this.goal, this.isWithdraw = false});

  @override
  ConsumerState<TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends ConsumerState<TopUpSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedAccountId;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? const [];
    if (accounts.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Buat akun dulu sebelum melakukan transaksi goal.',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1E2A),
            ),
          ),
        ),
      );
    }

    _selectedAccountId ??=
        ref.read(activeAccountIdProvider) ?? accounts.first.id;
    final selected = accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => accounts.first,
    );

    final amount = CurrencySettings.parseInputToIdr(_amountController.text);
    final verb = widget.isWithdraw ? 'dipindah ke' : 'dipindah dari';
    final confirmText = amount <= 0
        ? '-'
        : '${CurrencySettings.format(amount)} akan $verb ${selected.name} ke ${widget.goal.name}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.isWithdraw ? 'Tarik Dana Goal' : 'Top Up Goal',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [_CurrencyThousandsFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: CurrencySettings.current.symbol,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
              decoration: const InputDecoration(labelText: 'Sumber Dana'),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedAccountId = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (opsional)',
                hintText: 'Tambahkan catatan',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A2033)
                    : const Color(0xFFF2F5FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF46516E),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final selectedId = _selectedAccountId;
                        if (selectedId == null) return;
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final parsedAmount = CurrencySettings.parseInputToIdr(
                          _amountController.text,
                        );
                        if (parsedAmount <= 0) return;

                        setState(() => _submitting = true);
                        if (!widget.isWithdraw) {
                          final repo = ref.read(accountRepositoryProvider);
                          final balance = await repo.getBalance(selectedId);
                          if (balance < parsedAmount) {
                            if (!mounted) return;
                            setState(() => _submitting = false);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Saldo akun tidak mencukupi'),
                              ),
                            );
                            return;
                          }
                        }

                        if (!mounted) return;
                        navigator.pop(
                          TopUpSheetResult(
                            amount: parsedAmount,
                            accountId: selectedId,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                          ),
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: widget.isWithdraw
                      ? const Color(0xFF22C1C3)
                      : const Color(0xFF4F6EF7),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isWithdraw
                            ? 'Konfirmasi Tarik Dana'
                            : 'Konfirmasi Top Up',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = CurrencySettings.decimalFormatter().format(
      int.tryParse(digits) ?? 0,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

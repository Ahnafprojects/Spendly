import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/analytics_notifier.dart';
import '../../budget/budget_notifier.dart';
import '../../transaction/transaction_notifier.dart';
import '../../spaces/space_notifier.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/widgets/app_notice.dart';
import '../account_model.dart';
import '../account_notifier.dart';
import '../transfer_service.dart';

class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _fromId;
  String? _toId;
  bool _submitting = false;
  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _parseAmount(String input) {
    return CurrencySettings.parseInputToIdr(input);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(transferServiceProvider)
          .transfer(
            fromId: _fromId!,
            toId: _toId!,
            amount: _parseAmount(_amountController.text),
            note: _noteController.text.trim(),
            spaceId: ref.read(activeSpaceIdProvider),
          );

      unawaited(
        ref.read(accountNotifierProvider.notifier).reload().catchError((_) {}),
      );
      ref.invalidate(accountBalancesProvider);
      unawaited(
        ref
            .read(transactionNotifierProvider.notifier)
            .refresh()
            .catchError((_) {}),
      );
      unawaited(
        ref.read(budgetNotifierProvider.notifier).reload().catchError((_) {}),
      );
      unawaited(
        ref
            .read(analyticsNotifierProvider.notifier)
            .refreshCurrentPeriod()
            .catchError((_) {}),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Transfer gagal', 'Transfer failed')}: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12192B) : Colors.white;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];

    if (accounts.length < 2) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _t(
              'Minimal butuh 2 akun untuk transfer.',
              'At least 2 accounts are needed for transfer.',
            ),
            style: TextStyle(color: title),
          ),
        ),
      );
    }

    _fromId ??= accounts.first.id;
    _toId ??= accounts.last.id;
    if (_fromId == _toId && accounts.length >= 2) {
      _toId = accounts[1].id;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t('Transfer Antar Akun', 'Transfer Between Accounts'),
              style: TextStyle(
                color: title,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _t(
                'Saldo akan berpindah otomatis antar dompet.',
                'Balance will be moved automatically between wallets.',
              ),
              style: TextStyle(
                color: title.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _fromId,
              decoration: InputDecoration(
                labelText: _t('Dari akun', 'From account'),
              ),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Row(
                        children: [
                          Icon(
                            accountIconData(a.icon),
                            size: 16,
                            color: a.colorValue,
                          ),
                          const SizedBox(width: 8),
                          Text(a.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _fromId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _toId,
              decoration: InputDecoration(
                labelText: _t('Ke akun', 'To account'),
              ),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Row(
                        children: [
                          Icon(
                            accountIconData(a.icon),
                            size: 16,
                            color: a.colorValue,
                          ),
                          const SizedBox(width: 8),
                          Text(a.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _toId = v),
              validator: (_) {
                if (_fromId == _toId) {
                  return _t(
                    'Akun tujuan harus berbeda',
                    'Destination account must be different',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    final from = _fromId;
                    _fromId = _toId;
                    _toId = from;
                  });
                },
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: Text(_t('Tukar akun', 'Swap accounts')),
              ),
            ),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [_CurrencyThousandsFormatter()],
              decoration: InputDecoration(
                labelText: _t('Nominal', 'Amount'),
                prefixText: '${CurrencySettings.current.symbol} ',
              ),
              validator: (v) {
                final amount = _parseAmount(v ?? '');
                if (amount <= 0) {
                  return _t(
                    'Nominal wajib lebih dari 0',
                    'Amount must be greater than 0',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: _t('Catatan (opsional)', 'Note (optional)'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F6EF7),
                ),
                child: Text(
                  _submitting
                      ? _t('Memproses...', 'Processing...')
                      : _t('Transfer', 'Transfer'),
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
      int.parse(digits),
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

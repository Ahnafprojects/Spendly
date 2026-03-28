import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../account/account_notifier.dart';
import '../../account/account_repository.dart';
import '../transaction_repository.dart';
import '../transaction_notifier.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel? initialTransaction;
  const AddTransactionScreen({super.key, this.initialTransaction});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'expense';
  String _category = TransactionCategories.expense.first;
  bool _isSubmitting = false;
  bool _showAllCategories = false;

  String _t(String id, String en) => AppText.t(id: id, en: en);

  List<String> get _activeCategories => _type == 'income'
      ? TransactionCategories.income
      : TransactionCategories.expense;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    if (tx != null) {
      _type = tx.type;
      _category = tx.category;
      _amountController.text = CurrencySettings.formatInputFromIdr(tx.amount);
      _noteController.text = tx.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _parseAmount() {
    return CurrencySettings.parseInputToIdr(_amountController.text);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final amount = _parseAmount();
      final now = DateTime.now();
      final note = _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim();
      final activeAccountId = ref.read(activeAccountIdProvider);
      if (activeAccountId == null || activeAccountId.isEmpty) {
        throw Exception(
          _t('Pilih akun terlebih dahulu', 'Select account first'),
        );
      }
      final initial = widget.initialTransaction;
      final currentBalance = await ref
          .read(accountRepositoryProvider)
          .getBalance(activeAccountId);

      double previousImpact = 0;
      if (initial != null && initial.accountId == activeAccountId) {
        if (initial.type == 'income') previousImpact = initial.amount;
        if (initial.type == 'expense') previousImpact = -initial.amount;
      }
      final newImpact = _type == 'income' ? amount : -amount;
      final resultingBalance = currentBalance - previousImpact + newImpact;
      if (resultingBalance < 0) {
        throw Exception(
          _t(
            'Saldo tidak cukup untuk pengeluaran ini',
            'Insufficient balance for this expense',
          ),
        );
      }

      if (initial == null) {
        final transaction = TransactionModel(
          id: '',
          userId: '',
          amount: amount,
          type: _type,
          category: _category,
          note: note,
          accountId: activeAccountId,
          date: now,
          createdAt: now,
        );
        await ref
            .read(transactionNotifierProvider.notifier)
            .addTransaction(transaction);
      } else {
        final originalDate = initial.date;
        final normalizedDate =
            originalDate.hour == 0 &&
                originalDate.minute == 0 &&
                originalDate.second == 0
            ? DateTime(
                originalDate.year,
                originalDate.month,
                originalDate.day,
                now.hour,
                now.minute,
                now.second,
              )
            : originalDate;
        final updated = TransactionModel(
          id: initial.id,
          userId: initial.userId,
          amount: amount,
          type: _type,
          category: _category,
          note: note,
          accountId: initial.accountId ?? activeAccountId,
          transferDirection: initial.transferDirection,
          transferGroupId: initial.transferGroupId,
          date: normalizedDate,
          createdAt: initial.createdAt,
        );
        await ref.read(transactionRepositoryProvider).update(updated);
      }
      if (!mounted) return;
      AppNotice.success(
        context,
        initial == null
            ? _t(
                'Transaksi berhasil ditambahkan',
                'Transaction added successfully',
              )
            : _t(
                'Transaksi berhasil diperbarui',
                'Transaction updated successfully',
              ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal menyimpan transaksi', 'Failed to save transaction')}: $e',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _type == 'income'
        ? const Color(0xFF00D4AA)
        : const Color(0xFF4F6EF7);
    ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F7FC);
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6275);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final pillBg = isDark ? const Color(0xFF171C2D) : const Color(0xFFEAF1FF);
    final chipBg = isDark ? const Color(0xFF181F31) : const Color(0xFFF0F4FF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          widget.initialTransaction == null
              ? _t('Tambah Transaksi', 'Add Transaction')
              : _t('Edit Transaksi', 'Edit Transaction'),
        ),
        backgroundColor: bg,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTypePill(
                          'expense',
                          _t('Pengeluaran', 'Expense'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTypePill(
                          'income',
                          _t('Pemasukan', 'Income'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildLabel(_t('Nominal', 'Amount')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CurrencyThousandsFormatter()],
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: title,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  decoration: _fieldDecoration(
                    '',
                    prefix: CurrencySettings.current.symbol.trim(),
                    isDark: isDark,
                    large: true,
                  ),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );
                    if (digits.isEmpty) {
                      return _t('Nominal wajib diisi', 'Amount is required');
                    }
                    final amount = double.tryParse(digits) ?? 0;
                    if (amount <= 0) {
                      return _t(
                        'Nominal harus lebih dari 0',
                        'Amount must be greater than 0',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                _buildLabel(_t('Kategori', 'Category')),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      (_showAllCategories
                              ? _activeCategories
                              : _activeCategories.take(8).toList())
                          .map((category) {
                            final selected = category == _category;
                            return ChoiceChip(
                              label: Text(localizeCategory(category)),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                              selectedColor: accent.withValues(alpha: 0.25),
                              backgroundColor: chipBg,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : muted,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: selected
                                      ? accent.withValues(alpha: 0.7)
                                      : Colors.white10,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            );
                          })
                          .toList(),
                ),
                if (_activeCategories.length > 8) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(
                      () => _showAllCategories = !_showAllCategories,
                    ),
                    child: Text(
                      _showAllCategories
                          ? _t(
                              'Sembunyikan sebagian kategori',
                              'Hide some categories',
                            )
                          : _t(
                              'Tampilkan kategori selengkapnya',
                              'Show all categories',
                            ),
                      style: const TextStyle(color: Color(0xFF4F6EF7)),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _buildLabel(_t('Catatan (opsional)', 'Note (optional)')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  style: TextStyle(color: title),
                  decoration: _fieldDecoration(
                    _t(
                      'Contoh: Makan siang di kantor',
                      'Example: Lunch at office',
                    ),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: accent.withValues(alpha: 0.5),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Center(
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _t('Simpan', 'Save'),
                              style: const TextStyle(
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
        ),
      ),
    );
  }

  Widget _buildTypePill(String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _type == value;
    final color = value == 'income'
        ? const Color(0xFF00D4AA)
        : const Color(0xFF4F6EF7);
    return GestureDetector(
      onTap: () => setState(() {
        _type = value;
        if (!_activeCategories.contains(_category)) {
          _category = _activeCategories.first;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.8) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark ? Colors.white60 : const Color(0xFF5B6275)),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      style: TextStyle(
        color: isDark ? Colors.white70 : const Color(0xFF5B6275),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String hint, {
    String? prefix,
    required bool isDark,
    bool large = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFF9AA4BD),
      ),
      prefixText: prefix == null ? null : '$prefix ',
      prefixStyle: TextStyle(
        color: isDark ? Colors.white54 : const Color(0xFF6D7892),
        fontSize: large ? 32 : 16,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF141B2E) : const Color(0xFFF7F9FF),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: large ? 24 : 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(large ? 24 : 14),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF28324A) : const Color(0xFFDDE5F7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(large ? 24 : 14),
        borderSide: const BorderSide(color: Color(0xFF4F6EF7), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(large ? 24 : 14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(large ? 24 : 14),
        borderSide: const BorderSide(color: Colors.redAccent),
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
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final number = int.parse(digitsOnly);
    final newText = CurrencySettings.decimalFormatter().format(number);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

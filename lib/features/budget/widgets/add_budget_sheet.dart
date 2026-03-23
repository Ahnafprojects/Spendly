import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/services/currency_settings.dart';
import '../budget_notifier.dart';

class AddBudgetSheet extends ConsumerStatefulWidget {
  final String? initialCategory;
  final double? initialAmount;
  const AddBudgetSheet({super.key, this.initialCategory, this.initialAmount});

  @override
  ConsumerState<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<AddBudgetSheet> {
  final _amountController = TextEditingController();
  String _selectedCategory = TransactionCategories.expense.first;
  final List<String> _categories = TransactionCategories.expense;
  bool _showAllCategories = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialAmount != null) {
      _amountController.text = CurrencySettings.decimalFormatter().format(
        widget.initialAmount!.toInt(),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141420) : const Color(0xFFF4F7FC);
    final card = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6275);
    final softMuted = isDark ? Colors.white54 : const Color(0xFF6D7892);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCFD8EC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Set Budget Kategori',
                style: TextStyle(
                  color: title,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [_IdrThousandsFormatter()],
                style: TextStyle(
                  color: title,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: CurrencySettings.current.symbol,
                  prefixStyle: TextStyle(color: softMuted, fontSize: 32),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : const Color(0xFFB9C4DC),
                    fontSize: 32,
                  ),
                  border: InputBorder.none,
                  filled: true,
                  fillColor: card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFF4F6EF7),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Pilih Kategori',
                style: TextStyle(color: muted, fontSize: 14),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _showAllCategories
                    ? _categories.length
                    : (_categories.length > 8 ? 8 : _categories.length),
                itemBuilder: (context, index) {
                  final displayedCategories = _showAllCategories
                      ? _categories
                      : _categories.take(8).toList();
                  final cat = displayedCategories[index];
                  final isSelected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4F6EF7) : card,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            categoryIconFor(cat),
                            color: isSelected ? Colors.white : softMuted,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : softMuted,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_categories.length > 8) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () =>
                      setState(() => _showAllCategories = !_showAllCategories),
                  child: Text(
                    _showAllCategories
                        ? 'Sembunyikan sebagian kategori'
                        : 'Tampilkan kategori selengkapnya',
                    style: const TextStyle(color: Color(0xFF4F6EF7)),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F6EF7), Color(0xFF00D4AA)],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    if (_amountController.text.isEmpty) return;
                    final digits = _amountController.text.replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );
                    if (digits.isEmpty) return;
                    final amount = double.parse(digits);
                    await ref
                        .read(budgetNotifierProvider.notifier)
                        .upsertBudget(_selectedCategory, amount);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    'Simpan Budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IdrThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue(text: '');
    final formatted = CurrencySettings.decimalFormatter().format(
      int.parse(digitsOnly),
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

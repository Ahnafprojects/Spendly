import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../savings_goal_model.dart';
import 'goal_card.dart';

class AddGoalSheet extends ConsumerStatefulWidget {
  final SavingsGoalModel? initialGoal;

  const AddGoalSheet({super.key, this.initialGoal});

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _initialController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _palette = const [
    '#4F6EF7',
    '#2E90FA',
    '#22C1C3',
    '#00D4AA',
    '#F59E0B',
    '#EF4444',
    '#EC4899',
    '#8B5CF6',
  ];

  late String _selectedIconKey;
  late String _selectedColor;
  late DateTime _targetDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialGoal;
    _nameController.text = initial?.name ?? '';
    _targetController.text = initial == null
        ? ''
        : CurrencySettings.formatInputFromIdr(initial.targetAmount);
    _initialController.text = initial == null
        ? ''
        : CurrencySettings.formatInputFromIdr(initial.currentAmount);
    _selectedIconKey = normalizeSavingsGoalIcon(initial?.icon ?? 'flag');
    _selectedColor = initial?.color ?? _palette.first;
    final now = DateTime.now();
    _targetDate =
        initial?.targetDate ??
        DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _initialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    ref.watch(appLanguageProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final minDate = DateTime.now().add(const Duration(days: 30));

    final previewGoal = SavingsGoalModel(
      id: widget.initialGoal?.id ?? '',
      userId: '',
      name: _nameController.text.trim().isEmpty
          ? 'Tujuan Baru'
          : _nameController.text.trim(),
      icon: _selectedIconKey,
      color: _selectedColor,
      targetAmount: _parse(_targetController.text),
      currentAmount: _parse(_initialController.text),
      targetDate: _targetDate,
      isCompleted:
          _parse(_targetController.text) > 0 &&
          _parse(_initialController.text) >= _parse(_targetController.text),
      createdAt: widget.initialGoal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    widget.initialGoal == null
                        ? 'Buat Savings Goal'
                        : 'Edit Savings Goal',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GoalCard(goal: previewGoal, compact: true, heroEnabled: false),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameController,
                  maxLength: 30,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration(
                    context,
                    label: 'Nama Goal',
                    hint: 'Contoh: DP Rumah',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Nama goal wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Icon Goal',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: savingsGoalIconOptions.map((option) {
                    final selected = option.key == _selectedIconKey;
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedIconKey = option.key),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF4F6EF7).withValues(alpha: 0.2)
                              : (isDark
                                    ? const Color(0xFF1A2033)
                                    : const Color(0xFFF3F6FD)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF4F6EF7)
                                : (isDark
                                      ? Colors.white12
                                      : const Color(0xFFD8E1F7)),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            option.icon,
                            size: 20,
                            color: selected
                                ? const Color(0xFF4F6EF7)
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF425173)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Warna Gradient',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _palette.map((hex) {
                    final selected = hex == _selectedColor;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedColor = hex),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _hexToColor(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _hexToColor(hex).withValues(alpha: 0.35),
                                blurRadius: selected ? 10 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CurrencyThousandsFormatter()],
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration(
                    context,
                    label: 'Target Amount',
                    hint: 'Masukkan target tabungan',
                    prefix: CurrencySettings.current.symbol,
                  ),
                  validator: (value) {
                    if (_parse(value ?? '') <= 0) {
                      return 'Target amount harus lebih dari 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _initialController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CurrencyThousandsFormatter()],
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration(
                    context,
                    label: 'Initial Deposit (opsional)',
                    hint: 'Mulai dengan berapa?',
                    prefix: CurrencySettings.current.symbol,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _targetDate.isBefore(minDate)
                          ? minDate
                          : _targetDate,
                      firstDate: minDate,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      locale: LanguageSettings.current.locale,
                    );
                    if (picked != null) {
                      setState(() => _targetDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2033) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFD7E0F4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF425173),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Target Date: ${DateFormat('dd MMM yyyy', LanguageSettings.current.locale.toString()).format(_targetDate)}',
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F6EF7),
                    ),
                    child: Text(
                      widget.initialGoal == null
                          ? 'Simpan Goal'
                          : 'Update Goal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required String hint,
    String? prefix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2033) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : const Color(0xFFD7E0F4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : const Color(0xFFD7E0F4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4F6EF7), width: 1.4),
      ),
      counterText: '',
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final targetAmount = _parse(_targetController.text);
    final initial = _parse(_initialController.text);
    final goal = SavingsGoalModel(
      id: widget.initialGoal?.id ?? '',
      userId: '',
      name: _nameController.text.trim(),
      icon: _selectedIconKey,
      color: _selectedColor,
      targetAmount: targetAmount,
      currentAmount: initial,
      targetDate: _targetDate,
      isCompleted: initial >= targetAmount && targetAmount > 0,
      createdAt: widget.initialGoal?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, goal);
  }

  double _parse(String text) => CurrencySettings.parseInputToIdr(text);

  Color _hexToColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(value, radix: 16) ?? 0xFF4F6EF7);
  }
}

class _CurrencyThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final number = int.tryParse(digits) ?? 0;
    final formatted = CurrencySettings.decimalFormatter().format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

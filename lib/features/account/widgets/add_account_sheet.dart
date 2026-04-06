import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/widgets/app_notice.dart';
import '../account_model.dart';
import '../account_notifier.dart';

enum AddAccountAction { added, updated, deleted }

class AddAccountSheetResult {
  final AddAccountAction action;
  final String accountName;

  const AddAccountSheetResult({
    required this.action,
    required this.accountName,
  });
}

class AddAccountSheet extends ConsumerStatefulWidget {
  final AccountModel? initial;
  const AddAccountSheet({super.key, this.initial});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  final List<String> _types = const [
    'cash',
    'bank',
    'ewallet',
    'investment',
    'other',
  ];
  final List<String> _colors = const [
    '#4F6EF7',
    '#00D4AA',
    '#F59E0B',
    '#EF4444',
    '#22C55E',
    '#0EA5E9',
    '#8B5CF6',
    '#EC4899',
    '#F97316',
    '#64748B',
  ];

  String _type = 'cash';
  String _icon = 'card';
  String _color = '#4F6EF7';
  bool _saving = false;
  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _nameController.text = initial.name;
      _balanceController.text = CurrencySettings.formatInputFromIdr(
        initial.initialBalance,
      );
      _type = initial.type;
      _icon = initial.icon;
      _color = initial.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  double _parseAmount(String input) {
    return CurrencySettings.parseInputToIdr(input);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final initial = widget.initial;
    final model = AccountModel(
      id: initial?.id ?? '',
      userId: initial?.userId ?? '',
      name: _nameController.text.trim(),
      type: _type,
      icon: _icon,
      color: _color,
      initialBalance: _parseAmount(_balanceController.text),
      isDefault: initial?.isDefault ?? false,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (initial == null) {
        await ref.read(accountNotifierProvider.notifier).add(model);
      } else {
        await ref.read(accountNotifierProvider.notifier).updateAccount(model);
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        AddAccountSheetResult(
          action: initial == null
              ? AddAccountAction.added
              : AddAccountAction.updated,
          accountName: model.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal menyimpan akun', 'Failed to save account')}: $e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final account = widget.initial;
    if (account == null || _saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Hapus akun?', 'Delete account?')),
        content: Text(
          _t(
            'Akun ini akan dihapus permanen jika saldo 0.',
            'This account will be deleted permanently if its balance is 0.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_t('Hapus', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(accountNotifierProvider.notifier)
          .deleteIfZeroBalance(account.id);
      if (!mounted) return;
      Navigator.pop(
        context,
        AddAccountSheetResult(
          action: AddAccountAction.deleted,
          accountName: account.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12192B) : Colors.white;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);

    return DraggableScrollableSheet(
      initialChildSize: 0.84,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 48,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.initial == null
                        ? _t('Tambah Akun', 'Add Account')
                        : _t('Edit Akun', 'Edit Account'),
                    style: TextStyle(
                      color: title,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A2338)
                          : const Color(0xFFEFF3FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFDDE5F7),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(
                            int.parse('FF${_color.substring(1)}', radix: 16),
                          ).withValues(alpha: 0.25),
                          child: Icon(
                            accountIconData(_icon),
                            size: 18,
                            color: Color(
                              int.parse('FF${_color.substring(1)}', radix: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.trim().isEmpty
                                    ? _t('Preview Akun', 'Account Preview')
                                    : _nameController.text.trim(),
                                style: TextStyle(
                                  color: title,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                accountTypeLabel(
                                  _type,
                                  isEnglish: AppText.isEnglish,
                                ),
                                style: TextStyle(
                                  color: title.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencySettings.formatCompact(
                            _parseAmount(_balanceController.text),
                          ),
                          style: TextStyle(
                            color: title,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t('Nama akun', 'Account name'),
                      hintText: _t('BCA / Gopay / Cash', 'BCA / Gopay / Cash'),
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return _t('Nama wajib diisi', 'Name is required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('Tipe akun', 'Account type'),
                    style: TextStyle(color: title),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = type == _type;
                      return ChoiceChip(
                        label: Text(
                          accountTypeLabel(type, isEnglish: AppText.isEnglish),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => _type = type),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('Pilih icon', 'Choose icon'),
                    style: TextStyle(color: title),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: accountIconOptions.map((option) {
                      final selected = option.key == _icon;
                      return InkWell(
                        onTap: () => setState(() => _icon = option.key),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF4F6EF7).withValues(alpha: 0.2)
                                : (isDark
                                      ? const Color(0xFF1B2439)
                                      : const Color(0xFFF1F5FF)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF4F6EF7)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            option.icon,
                            size: 20,
                            color: selected
                                ? const Color(0xFF4F6EF7)
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF24314F)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('Warna akun', 'Account color'),
                    style: TextStyle(color: title),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colors.map((hex) {
                      final color = Color(
                        int.parse('FF${hex.substring(1)}', radix: 16),
                      );
                      final selected = hex == _color;
                      return InkWell(
                        onTap: () => setState(() => _color = hex),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_CurrencyThousandsFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _t('Saldo awal', 'Initial balance'),
                      prefixText: '${CurrencySettings.current.symbol} ',
                    ),
                    validator: (v) {
                      final amount = _parseAmount(v ?? '');
                      if (amount < 0) {
                        return _t(
                          'Saldo tidak boleh negatif',
                          'Balance cannot be negative',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F6EF7), Color(0xFF00D4AA)],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _saving
                              ? _t('Menyimpan...', 'Saving...')
                              : _t('Simpan', 'Save'),
                        ),
                      ),
                    ),
                  ),
                  if (widget.initial != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _deleteAccount,
                        icon: const Icon(Icons.delete_outline_rounded),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                        ),
                        label: Text(_t('Hapus Akun', 'Delete Account')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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

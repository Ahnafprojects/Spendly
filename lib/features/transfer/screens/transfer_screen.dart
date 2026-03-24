import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/widgets/app_notice.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  static const _storageKey = 'savings_goals_v1';
  bool _loading = true;
  List<_GoalItem> _goals = [];
  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      setState(() {
        _goals = [];
        _loading = false;
      });
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw Exception('invalid');
      final parsed =
          decoded
              .whereType<Map>()
              .map((e) => _GoalItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _goals = parsed;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _goals = [];
        _loading = false;
      });
    }
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_goals.map((e) => e.toJson()).toList()),
    );
  }

  String _id() =>
      '${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}';

  Future<void> _showGoalForm({_GoalItem? initial}) async {
    final titleC = TextEditingController(text: initial?.title ?? '');
    final targetC = TextEditingController(
      text: initial == null
          ? ''
          : CurrencySettings.formatInputFromIdr(initial.target),
    );
    final currentC = TextEditingController(
      text: initial == null
          ? ''
          : CurrencySettings.formatInputFromIdr(initial.current),
    );
    DateTime? selectedDeadline = initial?.deadline;
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF12192B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        initial == null
                            ? _t('Buat Target Nabung', 'Create Savings Goal')
                            : _t('Edit Target', 'Edit Goal'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1E2A),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: titleC,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1E2A),
                        ),
                        decoration: _inputDecoration(
                          context,
                          isDark: isDark,
                          hint: _t(
                            'Nama target (contoh: Dana Darurat)',
                            'Goal name (example: Emergency Fund)',
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return _t(
                              'Nama target wajib diisi',
                              'Goal name is required',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: targetC,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_CurrencyThousandsFormatter()],
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1E2A),
                        ),
                        decoration: _inputDecoration(
                          context,
                          isDark: isDark,
                          hint: _t('Target nominal', 'Target amount'),
                          prefix: CurrencySettings.current.symbol,
                        ),
                        validator: (v) {
                          final n = _parse(v);
                          if (n <= 0) {
                            return _t(
                              'Target harus lebih dari 0',
                              'Target must be greater than 0',
                            );
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: currentC,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_CurrencyThousandsFormatter()],
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1E2A),
                        ),
                        decoration: _inputDecoration(
                          context,
                          isDark: isDark,
                          hint: _t(
                            'Saldo awal (opsional)',
                            'Initial amount (optional)',
                          ),
                          prefix: CurrencySettings.current.symbol,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              selectedDeadline == null
                                  ? _t(
                                      'Deadline: belum dipilih',
                                      'Deadline: not selected',
                                    )
                                  : '${_t('Deadline', 'Deadline')}: ${DateFormat('dd MMM yyyy', LanguageSettings.current.locale.toString()).format(selectedDeadline!)}',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF5B6275),
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      selectedDeadline ??
                                      DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                  locale: LanguageSettings.current.locale,
                                );
                                if (picked != null) {
                                  setLocal(() => selectedDeadline = picked);
                                }
                              },
                              child: Text(_t('Pilih Tanggal', 'Pick Date')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E90FA),
                          ),
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            Navigator.pop(ctx, true);
                          },
                          child: Text(
                            initial == null
                                ? _t('Simpan Target', 'Save Goal')
                                : _t('Update Target', 'Update Goal'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;
    final item = _GoalItem(
      id: initial?.id ?? _id(),
      title: titleC.text.trim(),
      target: _parse(targetC.text),
      current: _parse(currentC.text),
      deadline: selectedDeadline,
      createdAt: initial?.createdAt ?? DateTime.now(),
    );

    setState(() {
      final idx = _goals.indexWhere((g) => g.id == item.id);
      if (idx >= 0) {
        _goals[idx] = item;
      } else {
        _goals.insert(0, item);
      }
    });
    await _saveGoals();
    if (!mounted) return;
    AppNotice.success(
      context,
      initial == null
          ? _t('Target tabungan dibuat', 'Savings goal created')
          : _t('Target tabungan diperbarui', 'Savings goal updated'),
    );
  }

  Future<void> _showDepositDialog(_GoalItem goal) async {
    final amountC = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(_t('Tambah Setoran', 'Add Deposit')),
          content: TextField(
            controller: amountC,
            keyboardType: TextInputType.number,
            inputFormatters: [_CurrencyThousandsFormatter()],
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1E2A),
            ),
            decoration: InputDecoration(
              prefixText: CurrencySettings.current.symbol,
              hintText: _t('Nominal setoran', 'Deposit amount'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_t('Batal', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t('Simpan', 'Save')),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    final value = _parse(amountC.text);
    if (value <= 0) {
      if (!mounted) return;
      AppNotice.warning(
        context,
        _t('Nominal setoran tidak valid', 'Invalid deposit amount'),
      );
      return;
    }
    setState(() {
      final idx = _goals.indexWhere((e) => e.id == goal.id);
      if (idx >= 0) {
        _goals[idx] = _goals[idx].copyWith(
          current: _goals[idx].current + value,
        );
      }
    });
    await _saveGoals();
    if (!mounted) return;
    AppNotice.success(
      context,
      _t('Setoran berhasil ditambahkan', 'Deposit added successfully'),
    );
  }

  Future<void> _deleteGoal(_GoalItem goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Hapus Target?', 'Delete Goal?')),
        content: Text(
          _t(
            'Target "${goal.title}" akan dihapus.',
            'Goal "${goal.title}" will be deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Hapus', 'Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _goals.removeWhere((g) => g.id == goal.id));
    await _saveGoals();
    if (!mounted) return;
    AppNotice.info(context, _t('Target dihapus', 'Goal deleted'));
  }

  double _parse(String? text) {
    return CurrencySettings.parseInputToIdr(text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F7FC);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          _t('Target Nabung', 'Savings Goals'),
          style: TextStyle(color: title),
        ),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalForm(),
        backgroundColor: const Color(0xFF2E90FA),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _t('Tambah', 'Add'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings_rounded,
                      size: 72,
                      color: isDark ? Colors.white24 : const Color(0xFFA4B3D2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('Belum ada target tabungan', 'No savings goals yet'),
                      style: TextStyle(
                        color: title,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        'Buat target pertama kamu, lalu isi setoran sedikit demi sedikit.',
                        'Create your first goal, then deposit gradually.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
              itemCount: _goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final g = _goals[index];
                final progress = g.target <= 0
                    ? 0.0
                    : (g.current / g.target).clamp(0.0, 1.0);
                final remaining = (g.target - g.current).clamp(
                  0.0,
                  double.infinity,
                );
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFDCE4F6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.title,
                              style: TextStyle(
                                color: title,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'deposit') {
                                await _showDepositDialog(g);
                              } else if (value == 'edit') {
                                await _showGoalForm(initial: g);
                              } else if (value == 'delete') {
                                await _deleteGoal(g);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'deposit',
                                child: Text(
                                  _t('Tambah Setoran', 'Add Deposit'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(_t('Edit Target', 'Edit Goal')),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(_t('Hapus Target', 'Delete Goal')),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${CurrencySettings.format(g.current)} / ${CurrencySettings.format(g.target)}',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF415073),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: progress,
                          backgroundColor: isDark
                              ? const Color(0xFF22314E)
                              : const Color(0xFFE5EDFC),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2E90FA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _metaChip(
                            isDark: isDark,
                            text:
                                '${_t('Sisa', 'Remaining')} ${CurrencySettings.formatCompact(remaining)}',
                          ),
                          _metaChip(
                            isDark: isDark,
                            text: '${(progress * 100).toStringAsFixed(1)}%',
                          ),
                          if (g.deadline != null)
                            _metaChip(
                              isDark: isDark,
                              text:
                                  '${_t('Deadline', 'Deadline')} ${DateFormat('dd MMM yyyy', LanguageSettings.current.locale.toString()).format(g.deadline!)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _metaChip({required bool isDark, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2840) : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF415073),
          fontSize: 11.5,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required bool isDark,
    required String hint,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFF95A2BD),
      ),
      prefixText: prefix,
      filled: true,
      fillColor: isDark ? const Color(0xFF1A2741) : const Color(0xFFF2F6FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : const Color(0xFFD7E2F9),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white10 : const Color(0xFFD7E2F9),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E90FA)),
      ),
    );
  }
}

class _GoalItem {
  final String id;
  final String title;
  final double target;
  final double current;
  final DateTime? deadline;
  final DateTime createdAt;

  const _GoalItem({
    required this.id,
    required this.title,
    required this.target,
    required this.current,
    required this.deadline,
    required this.createdAt,
  });

  _GoalItem copyWith({
    String? id,
    String? title,
    double? target,
    double? current,
    DateTime? deadline,
    DateTime? createdAt,
  }) {
    return _GoalItem(
      id: id ?? this.id,
      title: title ?? this.title,
      target: target ?? this.target,
      current: current ?? this.current,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory _GoalItem.fromJson(Map<String, dynamic> json) {
    return _GoalItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      target: (json['target'] as num?)?.toDouble() ?? 0,
      current: (json['current'] as num?)?.toDouble() ?? 0,
      deadline: json['deadline'] == null
          ? null
          : DateTime.tryParse(json['deadline'].toString()),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'target': target,
      'current': current,
      'deadline': deadline?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
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

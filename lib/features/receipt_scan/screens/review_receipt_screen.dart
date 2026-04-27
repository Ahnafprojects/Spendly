import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../transaction/transaction_repository.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/widgets/app_notice.dart';
import '../ocr_notifier.dart';
import '../receipt_data_model.dart';

class ReviewReceiptScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final String? transactionId;

  const ReviewReceiptScreen({
    super.key,
    required this.imagePath,
    this.transactionId,
  });

  @override
  ConsumerState<ReviewReceiptScreen> createState() =>
      _ReviewReceiptScreenState();
}

class _ReviewReceiptScreenState extends ConsumerState<ReviewReceiptScreen> {
  final _storeController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _date;
  String _category = 'Lainnya';
  bool _showItems = true;
  bool _previewExpanded = true;
  List<ReceiptItemData> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _storeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final file = File(widget.imagePath);
    final data = await ref.read(ocrNotifierProvider.notifier).scan(file);
    if (data == null) return;
    _apply(data);
  }

  void _apply(ReceiptData data) {
    _storeController.text = data.storeName ?? '';
    _amountController.text = data.totalAmount == null
        ? ''
        : CurrencySettings.formatInputFromIdr(data.totalAmount!);
    _date = data.date ?? DateTime.now();
    _category = data.suggestedCategory;
    _items = data.items;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ocrNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6275);
    final bg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);
    final receipt = state.receiptData;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Review Struk')),
      body: state.isScanning
          ? _ProcessingView(
              imagePath: widget.imagePath,
              step: state.processingStep,
            )
          : receipt == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error ?? 'Belum ada data struk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () =>
                          context.pushReplacementNamed('scan-receipt'),
                      child: const Text('Scan Ulang'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.pushNamed('add-transaction'),
                      child: const Text('Isi Manual'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => _previewExpanded = !_previewExpanded),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AnimatedCrossFade(
                        firstChild: Image.file(
                          File(widget.imagePath),
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        secondChild: Image.file(
                          File(widget.imagePath),
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        crossFadeState: _previewExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 220),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Data Terdeteksi',
                        style: TextStyle(
                          color: title,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _ConfidenceBadge(value: receipt.confidence),
                    ],
                  ),
                  if (receipt.confidence < 75) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFB020),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Harap periksa kembali data di bawah.',
                        style: TextStyle(
                          color: Color(0xFFFFB020),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const _FieldLabel(text: 'Nama toko'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _storeController,
                    decoration: _decoration('Contoh: Indomaret'),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(text: 'Tanggal'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: InputDecorator(
                      decoration: _decoration('Pilih tanggal'),
                      child: Text(
                        _date == null
                            ? 'Pilih tanggal'
                            : DateFormat('dd MMM yyyy').format(_date!),
                        style: TextStyle(color: title),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(text: 'Total'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: title,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: _decoration(
                      '0',
                      prefix: CurrencySettings.current.symbol,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(text: 'Kategori'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TransactionCategories.expense.take(10).map((
                      item,
                    ) {
                      final selected = item == _category;
                      return ChoiceChip(
                        label: Text(localizeCategory(item)),
                        selected: selected,
                        onSelected: (_) => setState(() => _category = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Item Terdeteksi',
                        style: TextStyle(
                          color: title,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showItems = !_showItems),
                        child: Text(_showItems ? 'Collapse' : 'Expand'),
                      ),
                    ],
                  ),
                  if (_showItems)
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return CheckboxListTile(
                        value: item.selected,
                        onChanged: (value) {
                          final updated = [..._items];
                          updated[index] = item.copyWith(
                            selected: value ?? true,
                          );
                          setState(() => _items = updated);
                        },
                        tileColor: item.isUncertain
                            ? const Color(0x22FFB020)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(color: title),
                              ),
                            ),
                            if (item.isUncertain)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x22FFB020),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Periksa',
                                  style: TextStyle(
                                    color: Color(0xFFFFB020),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          item.isUncertain
                              ? 'Item ini terdeteksi kurang yakin. Cek nama atau harga.'
                              : item.price == null
                              ? 'Harga tidak terbaca'
                              : CurrencySettings.format(item.price!),
                          style: TextStyle(color: muted),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pushReplacementNamed(
                            'scan-receipt',
                            extra: ReceiptScanArgs(
                              transactionId: widget.transactionId,
                            ),
                          ),
                          child: const Text('Scan Ulang'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4F6EF7), Color(0xFF6B3FE7)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: _saveToTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            child: const Text('Simpan Transaksi'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _saveToTransaction() async {
    final amount = CurrencySettings.parseInputToIdr(_amountController.text);
    if (amount <= 0) {
      AppNotice.error(context, 'Total struk belum valid.');
      return;
    }
    final noteBase = _storeController.text.trim().isEmpty
        ? 'Struk belanja'
        : _storeController.text.trim();
    final selectedCount = _items.where((item) => item.selected).length;
    final note =
        '$noteBase${selectedCount > 0 ? ' • $selectedCount item' : ''}';
    if (!mounted) return;
    final receiptData = ReceiptData(
      storeName: _storeController.text.trim().isEmpty
          ? null
          : _storeController.text.trim(),
      date: _date,
      totalAmount: amount,
      items: _items,
      confidence: ref.read(ocrNotifierProvider).receiptData?.confidence ?? 0,
      suggestedCategory: _category,
      imagePath: widget.imagePath,
    );
    final transactionId = widget.transactionId;
    if (transactionId != null && transactionId.isNotEmpty) {
      await ref
          .read(transactionRepositoryProvider)
          .saveReceiptMetadata(transactionId, receiptData.toJson());
      if (!mounted) return;
      context.pop(true);
      return;
    }
    context.pushNamed(
      'add-transaction',
      extra: ReceiptTransactionDraft(
        amount: amount,
        category: _category,
        note: note,
        date: _date,
        receiptData: receiptData,
      ),
    );
  }

  InputDecoration _decoration(String hint, {String? prefix}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      prefixText: prefix == null ? null : '$prefix ',
      filled: true,
      fillColor: isDark ? const Color(0xFF141B2E) : const Color(0xFFF7F9FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  final String imagePath;
  final int step;

  const _ProcessingView({required this.imagePath, required this.step});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Menunggu...',
      'Memproses gambar...',
      'Mengekstrak data...',
      'Selesai!',
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(
              File(imagePath),
              height: 280,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 28),
          const _ProgressDots(),
          const SizedBox(height: 18),
          const Text(
            'Membaca struk...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...List.generate(3, (index) {
            final active = step >= index + 1;
            final text = labels[index + 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(active ? '✅' : '•'),
                  const SizedBox(width: 8),
                  Text(text),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Text(
            'Estimasi 3-5 detik',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatefulWidget {
  const _ProgressDots();

  @override
  State<_ProgressDots> createState() => _ProgressDotsState();
}

class _ProgressDotsState extends State<_ProgressDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final active = ((_controller.value * 3).floor() % 3) == index;
            return Container(
              width: active ? 16 : 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF4F6EF7) : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final int value;

  const _ConfidenceBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 85
        ? const Color(0xFF159A6E)
        : value >= 70
        ? const Color(0xFFFFB020)
        : const Color(0xFFE2564D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Akurasi deteksi: $value%',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
  }
}

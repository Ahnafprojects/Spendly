import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../receipt_scan/receipt_data_model.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/widgets/app_notice.dart';
import '../transaction_repository.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final TransactionModel transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _deleting = false;
  String _t(String id, String en) => AppText.t(id: id, en: en);

  Future<void> _onEdit() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionScreen(initialTransaction: widget.transaction),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _onDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Hapus transaksi?', 'Delete transaction?')),
        content: Text(
          _t(
            'Transaksi ini akan dihapus permanen.',
            'This transaction will be deleted permanently.',
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

    setState(() => _deleting = true);
    try {
      final repository = ref.read(transactionRepositoryProvider);
      await repository.delete(widget.transaction.id);
      await repository.deleteReceiptMetadata(widget.transaction.id);
      if (!mounted) return;
      AppNotice.info(context, _t('Transaksi dihapus', 'Transaction deleted'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal hapus transaksi', 'Failed to delete transaction')}: $e',
      );
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);
    final tx = widget.transaction;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F7FC);
    final card = isDark ? const Color(0xFF151A2A) : Colors.white;
    final border = isDark ? Colors.white10 : const Color(0xFFDDE5F7);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);
    final isIncome = tx.type == 'income';
    final amountColor = isIncome
        ? const Color(0xFF00D4AA)
        : const Color(0xFFFF5A6E);
    final sign = isIncome ? '+' : '-';
    final amount = CurrencySettings.format(tx.amount);
    final displayDate =
        tx.date.hour == 0 && tx.date.minute == 0 && tx.date.second == 0
        ? tx.createdAt
        : tx.date;
    final date = DateFormat(
      'dd MMM yyyy, HH:mm:ss',
      LanguageSettings.current.locale.toString(),
    ).format(displayDate);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(_t('Detail Transaksi', 'Transaction Detail')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$sign$amount',
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _infoRow(
                  _t('Kategori', 'Category'),
                  localizeCategory(tx.category),
                  muted,
                  title,
                ),
                _infoRow(
                  _t('Tipe', 'Type'),
                  tx.type == 'income'
                      ? _t('Pemasukan', 'Income')
                      : _t('Pengeluaran', 'Expense'),
                  muted,
                  title,
                ),
                _infoRow(_t('Waktu', 'Time'), date, muted, title),
                _infoRow(
                  _t('Catatan', 'Note'),
                  tx.note?.isNotEmpty == true ? tx.note! : '-',
                  muted,
                  title,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<Map<String, dynamic>?>(
            future: _loadReceiptMetadata(tx.id),
            builder: (context, snapshot) {
              final raw = snapshot.data;
              if (raw == null || raw.isEmpty) {
                return const SizedBox.shrink();
              }
              final receipt = ReceiptData.fromJson(raw);
              final hasImage = receipt.imagePath.isNotEmpty;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: Color(0xFF4F6EF7),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _t('Struk Tersimpan', 'Saved Receipt'),
                          style: TextStyle(
                            color: title,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (hasImage)
                      GestureDetector(
                        onTap: () => _openReceiptPreview(receipt.imagePath),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(receipt.imagePath),
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    if (hasImage) const SizedBox(height: 14),
                    _infoRow(
                      _t('Toko', 'Store'),
                      receipt.storeName?.trim().isNotEmpty == true
                          ? receipt.storeName!
                          : '-',
                      muted,
                      title,
                    ),
                    _infoRow(
                      _t('Akurasi OCR', 'OCR Accuracy'),
                      '${receipt.confidence}%',
                      muted,
                      title,
                    ),
                    if (receipt.items.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(
                            _t('Item Terdeteksi', 'Detected Items'),
                            '${receipt.items.length}',
                            muted,
                            title,
                          ),
                          const SizedBox(height: 4),
                          ...receipt.items
                              .take(8)
                              .map(
                                (item) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.isUncertain
                                        ? const Color(0x14FFB020)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: item.isUncertain
                                          ? const Color(0x33FFB020)
                                          : border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${item.qty}x ${item.name}',
                                          style: TextStyle(
                                            color: title,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (item.isUncertain)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Text(
                                            'Periksa',
                                            style: TextStyle(
                                              color: Color(0xFFFFB020),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        item.price == null
                                            ? '-'
                                            : CurrencySettings.format(
                                                item.price!,
                                              ),
                                        style: TextStyle(color: muted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          if (receipt.items.length > 8)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '+${receipt.items.length - 8} item lainnya',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hasImage)
                          TextButton.icon(
                            onPressed: () =>
                                _openReceiptPreview(receipt.imagePath),
                            icon: const Icon(Icons.open_in_full_rounded),
                            label: Text(
                              _t('Lihat Struk Asli', 'View Original Receipt'),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _replaceReceipt,
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: Text(_t('Ganti Struk', 'Replace Receipt')),
                        ),
                        TextButton.icon(
                          onPressed: _removeReceipt,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(_t('Hapus Struk', 'Remove Receipt')),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _onEdit,
              icon: const Icon(Icons.edit_rounded),
              label: Text(_t('Edit Transaksi', 'Edit Transaction')),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _deleting ? null : _onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A6E),
              ),
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              label: Text(
                _deleting
                    ? _t('Menghapus...', 'Deleting...')
                    : _t('Hapus Transaksi', 'Delete Transaction'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadReceiptMetadata(
    String transactionId,
  ) async {
    return ref
        .read(transactionRepositoryProvider)
        .readReceiptMetadata(transactionId);
  }

  Future<void> _replaceReceipt() async {
    final changed = await context.pushNamed<bool>(
      'scan-receipt',
      extra: ReceiptScanArgs(transactionId: widget.transaction.id),
    );
    if (changed == true && mounted) {
      setState(() {});
      AppNotice.success(context, _t('Struk diperbarui', 'Receipt updated'));
    }
  }

  Future<void> _removeReceipt() async {
    await ref
        .read(transactionRepositoryProvider)
        .deleteReceiptMetadata(widget.transaction.id);
    if (!mounted) return;
    setState(() {});
    AppNotice.info(context, _t('Struk dihapus', 'Receipt removed'));
  }

  Future<void> _openReceiptPreview(String imagePath) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color muted, Color title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(color: title, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

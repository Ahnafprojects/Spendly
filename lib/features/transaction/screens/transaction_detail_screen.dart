import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      await ref
          .read(transactionRepositoryProvider)
          .delete(widget.transaction.id);
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

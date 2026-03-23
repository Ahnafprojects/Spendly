import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../shared/services/currency_settings.dart';
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
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
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
      AppNotice.info(context, 'Transaksi dihapus');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, 'Gagal hapus transaksi: $e');
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
      'id_ID',
    ).format(displayDate);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Detail Transaksi'),
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
                _infoRow('Kategori', tx.category, muted, title),
                _infoRow(
                  'Tipe',
                  tx.type == 'income' ? 'Income' : 'Expense',
                  muted,
                  title,
                ),
                _infoRow('Waktu', date, muted, title),
                _infoRow(
                  'Catatan',
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
              label: const Text('Edit Transaksi'),
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
              label: Text(_deleting ? 'Menghapus...' : 'Hapus Transaksi'),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../account/account_notifier.dart';
import 'transaction_detail_screen.dart';
import '../transaction_repository.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  late Future<List<TransactionModel>> _future;
  final _searchController = TextEditingController();
  String _query = '';
  DateTime? _selectedDate;
  String? _lastAccountId;

  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<TransactionModel>> _load() {
    final accountId = ref.read(activeAccountIdProvider);
    return ref
        .read(transactionRepositoryProvider)
        .fetchAll(accountId: accountId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickDateFilter() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      locale: LanguageSettings.current.locale,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeAccountId = ref.watch(activeAccountIdProvider);
    if (_lastAccountId != activeAccountId) {
      _lastAccountId = activeAccountId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _future = _load());
      });
    }
    ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F7FC);
    final card = isDark ? const Color(0xFF151A2A) : Colors.white;
    final border = isDark ? Colors.white10 : const Color(0xFFDDE5F7);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(_t('Riwayat Transaksi', 'Transaction History')),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<TransactionModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerCardList();
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${_t('Gagal memuat riwayat', 'Failed to load history')}:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.redAccent : const Color(0xFFB3261E),
                ),
              ),
            );
          }
          final data = snapshot.data ?? [];
          final sorted = [...data]
            ..sort((a, b) {
              final ad =
                  a.date.hour == 0 && a.date.minute == 0 && a.date.second == 0
                  ? a.createdAt
                  : a.date;
              final bd =
                  b.date.hour == 0 && b.date.minute == 0 && b.date.second == 0
                  ? b.createdAt
                  : b.date;
              return bd.compareTo(ad);
            });
          final keyword = _query.trim().toLowerCase();
          final filtered = keyword.isEmpty
              ? sorted
              : sorted.where((tx) {
                  final note = (tx.note ?? '').toLowerCase();
                  final cat = tx.category.toLowerCase();
                  final type = tx.type.toLowerCase();
                  final amount = tx.amount.toStringAsFixed(0);
                  return note.contains(keyword) ||
                      cat.contains(keyword) ||
                      type.contains(keyword) ||
                      amount.contains(keyword);
                }).toList();
          final dateFiltered = _selectedDate == null
              ? filtered
              : filtered.where((tx) {
                  final source =
                      tx.date.hour == 0 &&
                          tx.date.minute == 0 &&
                          tx.date.second == 0
                      ? tx.createdAt
                      : tx.date;
                  return source.year == _selectedDate!.year &&
                      source.month == _selectedDate!.month &&
                      source.day == _selectedDate!.day;
                }).toList();

          if (sorted.isEmpty) {
            return Center(
              child: Text(
                _t('Belum ada transaksi', 'No transactions yet'),
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF5B6275),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: TextStyle(color: title),
                  decoration: InputDecoration(
                    hintText: _t(
                      'Cari kategori / catatan / nominal',
                      'Search category / note / amount',
                    ),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : const Color(0xFF9AA4BD),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white54 : const Color(0xFF6D7892),
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF151A2A) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFDDE5F7),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFDDE5F7),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4F6EF7)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDateFilter,
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(
                        _selectedDate == null
                            ? _t('Filter tanggal', 'Filter date')
                            : DateFormat(
                                'dd MMM yyyy',
                                LanguageSettings.current.locale.toString(),
                              ).format(_selectedDate!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedDate != null)
                      TextButton(
                        onPressed: () => setState(() => _selectedDate = null),
                        child: Text(_t('Reset tanggal', 'Reset date')),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (dateFiltered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Center(
                      child: Text(
                        _t(
                          'Tidak ada transaksi yang cocok',
                          'No matching transactions found',
                        ),
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ),
                ...List.generate(dateFiltered.length, (index) {
                  final tx = dateFiltered[index];
                  final isIncome =
                      tx.type == 'income' ||
                      (tx.type == 'transfer' && tx.transferDirection == 'in');
                  final sign = isIncome ? '+' : '-';
                  final amountColor = isIncome
                      ? const Color(0xFF00D4AA)
                      : const Color(0xFFFF5A6E);
                  final amount = CurrencySettings.format(tx.amount);
                  final displayDate =
                      tx.date.hour == 0 &&
                          tx.date.minute == 0 &&
                          tx.date.second == 0
                      ? tx.createdAt
                      : tx.date;
                  final date = DateFormat(
                    'dd MMM yyyy, HH:mm:ss',
                    LanguageSettings.current.locale.toString(),
                  ).format(displayDate);

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == dateFiltered.length - 1 ? 0 : 10,
                    ),
                    child: InkWell(
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                TransactionDetailScreen(transaction: tx),
                          ),
                        );
                        if (changed == true) {
                          await _refresh();
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E2437)
                                    : const Color(0xFFE9EEFA),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                categoryIconFor(tx.category),
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF24314F),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.note?.isNotEmpty == true
                                        ? tx.note!
                                        : localizeCategory(tx.category),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: title,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${localizeCategory(tx.category)} • $date',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$sign$amount',
                                  style: TextStyle(
                                    color: amountColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white38
                                      : const Color(0xFF8D96AA),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

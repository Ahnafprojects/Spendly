import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/services/language_settings.dart';
import '../../shared/services/offline_store.dart';

// Model bantuan untuk Chart
class CategoryMetric {
  final String category;
  final double amount;
  CategoryMetric(this.category, this.amount);
}

class BarMetric {
  final String label; // 'Sen', 'Sel', atau 'Jan', 'Feb'
  final double income;
  final double expense;
  BarMetric(this.label, this.income, this.expense);
}

class AnalyticsRepository {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;

  AnalyticsRepository({
    SupabaseClient? supabase,
    required OfflineStore offlineStore,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _offlineStore = offlineStore;

  bool _isIncome(TransactionModel tx) {
    return tx.type == 'income' ||
        (tx.type == 'transfer' && tx.transferDirection == 'in');
  }

  bool _isExpense(TransactionModel tx) {
    return tx.type == 'expense' ||
        (tx.type == 'transfer' && tx.transferDirection == 'out');
  }

  Future<String> _resolveUserId() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.isNotEmpty) {
      await _offlineStore.saveLastUserId(authId);
      return authId;
    }
    final cached = await _offlineStore.readLastUserId();
    if (cached != null && cached.isNotEmpty) return cached;
    throw Exception('User belum login');
  }

  // Mengambil data berdasarkan rentang tanggal
  Future<List<TransactionModel>> fetchTransactionsByDateRange(
    DateTime start,
    DateTime end, {
    String? accountId,
  }) async {
    final userId = await _resolveUserId();

    try {
      var query = _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('date', start.toIso8601String())
          .lte('date', end.toIso8601String());
      if (accountId != null) {
        query = query.eq('account_id', accountId);
      }
      final response = await query;
      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.map((e) => TransactionModel.fromJson(e)).toList();
    } catch (_) {
      final local = await _offlineStore.readTransactions(userId);
      return local
          .map((e) => TransactionModel.fromJson(e))
          .where(
            (tx) =>
                !tx.date.isBefore(start) &&
                !tx.date.isAfter(end) &&
                (accountId == null || tx.accountId == accountId),
          )
          .toList();
    }
  }

  // GROUP BY Kategori (Mewakili SQL: SELECT category, SUM(amount)... GROUP BY)
  List<CategoryMetric> getCategoryBreakdown(
    List<TransactionModel> transactions,
  ) {
    final Map<String, double> grouped = {};
    for (var tx in transactions.where(_isExpense)) {
      grouped[tx.category] = (grouped[tx.category] ?? 0) + tx.amount;
    }

    final result = grouped.entries
        .map((e) => CategoryMetric(e.key, e.value))
        .toList();
    result.sort((a, b) => b.amount.compareTo(a.amount)); // ORDER BY sum DESC
    return result;
  }

  // Menghasilkan data Bar Chart (Income vs Expense)
  List<BarMetric> getBarMetrics(
    List<TransactionModel> transactions,
    String period,
  ) {
    final now = DateTime.now();
    final locale = LanguageSettings.current.locale.toString();

    if (period == 'Weekly') {
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      return List.generate(7, (index) {
        final day = start.add(Duration(days: index));
        final dayTx = transactions.where(
          (tx) =>
              tx.date.year == day.year &&
              tx.date.month == day.month &&
              tx.date.day == day.day,
        );

        final income = dayTx
            .where(_isIncome)
            .fold<double>(0, (sum, tx) => sum + tx.amount);
        final expense = dayTx
            .where(_isExpense)
            .fold<double>(0, (sum, tx) => sum + tx.amount);

        return BarMetric(DateFormat('E', locale).format(day), income, expense);
      });
    }

    if (period == 'Monthly') {
      final currentMonthTx = transactions.where(
        (tx) => tx.date.year == now.year && tx.date.month == now.month,
      );
      return List.generate(5, (index) {
        final weekIndex = index + 1;
        final weekTx = currentMonthTx.where(
          (tx) => (((tx.date.day - 1) ~/ 7) + 1) == weekIndex,
        );

        final income = weekTx
            .where(_isIncome)
            .fold<double>(0, (sum, tx) => sum + tx.amount);
        final expense = weekTx
            .where(_isExpense)
            .fold<double>(0, (sum, tx) => sum + tx.amount);

        return BarMetric('W$weekIndex', income, expense);
      });
    }

    return List.generate(12, (index) {
      final month = index + 1;
      final monthTx = transactions.where(
        (tx) => tx.date.year == now.year && tx.date.month == month,
      );
      final income = monthTx
          .where(_isIncome)
          .fold<double>(0, (sum, tx) => sum + tx.amount);
      final expense = monthTx
          .where(_isExpense)
          .fold<double>(0, (sum, tx) => sum + tx.amount);

      return BarMetric(
        DateFormat('MMM', locale).format(DateTime(now.year, month, 1)),
        income,
        expense,
      );
    });
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(offlineStore: OfflineStore());
});

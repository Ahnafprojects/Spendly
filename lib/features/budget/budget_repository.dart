import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/constants/transaction_categories.dart';
import '../../shared/services/offline_store.dart';
import 'models/budget_usage_model.dart';

class BudgetRepository {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;

  BudgetRepository({
    SupabaseClient? supabase,
    required OfflineStore offlineStore,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _offlineStore = offlineStore;

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

  bool get _canHitRemote => _supabase.auth.currentUser != null;

  Future<void> _syncPendingBudgetOps(String userId) async {
    final ops = await _offlineStore.readPendingBudgetOps(userId);
    if (ops.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final op in ops) {
      try {
        final type = (op['op'] ?? '').toString();
        final payload = Map<String, dynamic>.from(op['payload'] as Map);
        if (type == 'upsert') {
          await _supabase
              .from('budgets')
              .upsert(payload, onConflict: 'user_id, category, month');
        } else if (type == 'delete') {
          await _supabase
              .from('budgets')
              .delete()
              .eq('user_id', userId)
              .eq('category', (payload['category'] ?? '').toString())
              .eq('month', (payload['month'] ?? '').toString());
        } else {
          remaining.add(op);
        }
      } catch (_) {
        remaining.add(op);
      }
    }

    await _offlineStore.writePendingBudgetOps(userId, remaining);
  }

  Future<List<BudgetUsageModel>> fetchBudgetUsage(DateTime month) async {
    final userId = await _resolveUserId();

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    final monthDateStr = DateFormat('yyyy-MM-dd').format(monthStart);
    final startStr = DateFormat('yyyy-MM-dd').format(monthStart);
    final endStr = DateFormat(
      'yyyy-MM-dd',
    ).format(monthEnd.subtract(const Duration(days: 1)));

    List<Map<String, dynamic>> budgets = [];
    List<Map<String, dynamic>> transactions = [];
    try {
      if (_canHitRemote) {
        await _syncPendingBudgetOps(userId);
      }
      final budgetsResponse = await _supabase
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .eq('month', monthDateStr);
      final transactionsResponse = await _supabase
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'expense')
          .gte('date', startStr)
          .lte('date', endStr);

      budgets = (budgetsResponse as List).cast<Map<String, dynamic>>();
      transactions = (transactionsResponse as List)
          .cast<Map<String, dynamic>>();
      await _offlineStore.writeBudgets(userId, budgets);
    } catch (_) {
      final localBudgets = await _offlineStore.readBudgets(userId);
      final localTransactions = await _offlineStore.readTransactions(userId);
      budgets = localBudgets
          .where((b) => (b['month'] ?? '').toString() == monthDateStr)
          .toList();
      transactions = localTransactions.where((tx) {
        final type = (tx['type'] ?? '').toString();
        final dateStr = (tx['date'] ?? '').toString();
        final dt = DateTime.tryParse(dateStr);
        if (dt == null) return false;
        return type == 'expense' &&
            !dt.isBefore(monthStart) &&
            dt.isBefore(monthEnd);
      }).toList();
    }

    final spentByCategoryKey = <String, double>{};
    for (final tx in transactions) {
      final category = (tx['category'] ?? '').toString();
      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
      final key = normalizeCategoryKey(category);
      spentByCategoryKey[key] = (spentByCategoryKey[key] ?? 0) + amount;
    }

    final result = <BudgetUsageModel>[];
    for (final budget in budgets) {
      final category = (budget['category'] ?? '').toString();
      final limit = (budget['limit_amount'] as num?)?.toDouble() ?? 0;
      final spent = spentByCategoryKey[normalizeCategoryKey(category)] ?? 0;
      final remaining = limit - spent;
      final double usagePct = limit > 0 ? ((spent / limit) * 100) : 0.0;

      result.add(
        BudgetUsageModel(
          category: category,
          limitAmount: limit,
          spentAmount: spent,
          remaining: remaining,
          usagePct: usagePct,
          isOver: spent > limit,
        ),
      );
    }

    result.sort((a, b) => b.usagePct.compareTo(a.usagePct));
    return result;
  }

  Future<void> upsertBudget(
    String category,
    double limitAmount,
    DateTime month,
  ) async {
    final userId = await _resolveUserId();

    final formattedMonth = DateFormat('yyyy-MM-01').format(month);
    final row = {
      'user_id': userId,
      'category': category,
      'limit_amount': limitAmount,
      'month': formattedMonth,
    };

    await _offlineStore.upsertBudget(userId, row);
    if (!_canHitRemote) {
      await _offlineStore.enqueuePendingBudgetOp(userId, 'upsert', row);
      return;
    }
    try {
      await _supabase
          .from('budgets')
          .upsert(row, onConflict: 'user_id, category, month');
    } catch (_) {
      await _offlineStore.enqueuePendingBudgetOp(userId, 'upsert', row);
    }
  }

  Future<void> deleteBudget(String category, DateTime month) async {
    final userId = await _resolveUserId();
    final formattedMonth = DateFormat('yyyy-MM-01').format(month);

    await _offlineStore.deleteBudget(userId, category, formattedMonth);
    if (!_canHitRemote) {
      await _offlineStore.enqueuePendingBudgetOp(userId, 'delete', {
        'category': category,
        'month': formattedMonth,
      });
      return;
    }
    try {
      await _supabase
          .from('budgets')
          .delete()
          .eq('user_id', userId)
          .eq('category', category)
          .eq('month', formattedMonth);
    } catch (_) {
      await _offlineStore.enqueuePendingBudgetOp(userId, 'delete', {
        'category': category,
        'month': formattedMonth,
      });
    }
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(offlineStore: OfflineStore());
});

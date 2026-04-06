import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/services/activity_log_service.dart';
import '../../shared/services/budget_checker.dart';
import '../account/account_notifier.dart';
import '../analytics/analytics_notifier.dart';
import '../budget/budget_notifier.dart';
import '../spaces/space_notifier.dart';
import 'transaction_repository.dart';

class TransactionNotifier extends AsyncNotifier<List<TransactionModel>> {
  late TransactionRepository _repository;

  @override
  FutureOr<List<TransactionModel>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    ref.watch(activeAccountIdProvider);
    ref.watch(activeSpaceIdProvider);
    return _fetchRecentTransactions();
  }

  Future<List<TransactionModel>> _fetchRecentTransactions() async {
    // Mengambil 5 transaksi terbaru untuk dashboard
    return _repository.fetchRecent(
      limit: 5,
      accountId: ref.read(activeAccountIdProvider),
      spaceId: ref.read(activeSpaceIdProvider),
    );
  }

  // Fungsi untuk Pull-to-refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchRecentTransactions());
    ref.invalidate(accountBalancesProvider);
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _repository.insert(
      transaction,
      spaceId: ref.read(activeSpaceIdProvider),
    );

    await BudgetChecker.checkAndNotify(transaction.date);

    ref.read(budgetNotifierProvider.notifier).reload();
    ref.invalidate(accountBalancesProvider);
    ref.invalidate(analyticsNotifierProvider);
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'add_transaction',
          description: 'Menambah transaksi ${transaction.category}',
          metadata: {
            'amount': transaction.amount,
            'category': transaction.category,
            'type': transaction.type,
          },
        );

    await refresh();
  }

  // Fungsi hapus transaksi yang langsung update UI
  Future<void> deleteTransaction(String id) async {
    // Simpan data lama untuk berjaga-jaga jika proses hapus gagal
    final previousState = state;

    // Update UI duluan (Optimistic update) biar terasa cepat
    if (state.hasValue) {
      state = AsyncValue.data(state.value!.where((tx) => tx.id != id).toList());
    }

    try {
      await _repository.delete(id);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(analyticsNotifierProvider);
      await ref
          .read(activityLogServiceProvider)
          .log(
            action: 'delete_transaction',
            description: 'Menghapus transaksi',
            metadata: {'transaction_id': id},
          );
    } catch (e) {
      // Jika gagal di database, kembalikan ke state awal
      state = previousState;
      throw Exception('Gagal menghapus transaksi');
    }
  }
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, List<TransactionModel>>(() {
      return TransactionNotifier();
    });

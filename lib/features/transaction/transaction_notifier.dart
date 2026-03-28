import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/services/budget_checker.dart';
import '../account/account_notifier.dart';
import '../budget/budget_notifier.dart';
import 'transaction_repository.dart';

class TransactionNotifier extends AsyncNotifier<List<TransactionModel>> {
  late TransactionRepository _repository;

  @override
  FutureOr<List<TransactionModel>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    ref.watch(activeAccountIdProvider);
    return _fetchRecentTransactions();
  }

  Future<List<TransactionModel>> _fetchRecentTransactions() async {
    // Mengambil 10 transaksi terbaru
    return _repository.fetchRecent(
      limit: 10,
      accountId: ref.read(activeAccountIdProvider),
    );
  }

  // Fungsi untuk Pull-to-refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchRecentTransactions());
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _repository.insert(transaction);

    await BudgetChecker.checkAndNotify(transaction.date);

    ref.read(budgetNotifierProvider.notifier).reload();

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

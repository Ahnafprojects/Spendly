import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'budget_repository.dart';
import 'models/budget_usage_model.dart';

class BudgetState {
  final DateTime selectedMonth;
  final List<BudgetUsageModel> usages;

  BudgetState({required this.selectedMonth, required this.usages});
}

class BudgetNotifier extends AsyncNotifier<BudgetState> {
  late BudgetRepository _repository;
  DateTime _currentMonth = DateTime.now();

  @override
  FutureOr<BudgetState> build() async {
    _repository = ref.watch(budgetRepositoryProvider);
    return _fetchData(_currentMonth);
  }

  Future<BudgetState> _fetchData(DateTime month) async {
    final usages = await _repository.fetchBudgetUsage(month);
    return BudgetState(selectedMonth: month, usages: usages);
  }

  Future<void> changeMonth(DateTime newMonth) async {
    _currentMonth = newMonth;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData(newMonth));
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData(_currentMonth));
  }

  Future<void> upsertBudget(String category, double limit) async {
    await _repository.upsertBudget(category, limit, _currentMonth);
    await reload();
  }

  Future<void> deleteBudget(String category) async {
    await _repository.deleteBudget(category, _currentMonth);
    await reload();
  }
}

final budgetNotifierProvider =
    AsyncNotifierProvider<BudgetNotifier, BudgetState>(() {
      return BudgetNotifier();
    });

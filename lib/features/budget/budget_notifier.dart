import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/activity_log_service.dart';
import '../account/account_notifier.dart';
import '../spaces/space_notifier.dart';
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
    ref.watch(activeAccountIdProvider);
    ref.watch(activeSpaceIdProvider);
    return _fetchData(_currentMonth);
  }

  Future<BudgetState> _fetchData(DateTime month) async {
    final usages = await _repository.fetchBudgetUsage(
      month,
      accountId: ref.read(activeAccountIdProvider),
      spaceId: ref.read(activeSpaceIdProvider),
    );
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
    await _repository.upsertBudget(
      category,
      limit,
      _currentMonth,
      ref.read(activeSpaceIdProvider),
    );
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'edit_budget',
          description:
              'Mengubah budget $category menjadi ${limit.toStringAsFixed(0)}',
          metadata: {'category': category, 'limit': limit},
        );
    await reload();
  }

  Future<void> deleteBudget(String category) async {
    await _repository.deleteBudget(
      category,
      _currentMonth,
      ref.read(activeSpaceIdProvider),
    );
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'delete_budget',
          description: 'Menghapus budget $category',
          metadata: {'category': category},
        );
    await reload();
  }
}

final budgetNotifierProvider =
    AsyncNotifierProvider<BudgetNotifier, BudgetState>(() {
      return BudgetNotifier();
    });

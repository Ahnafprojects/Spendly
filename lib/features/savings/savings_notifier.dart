import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/activity_log_service.dart';
import '../../shared/services/notification_service.dart';
import '../account/account_notifier.dart';
import '../spaces/space_notifier.dart';
import '../transaction/transaction_notifier.dart';
import 'savings_deposit_model.dart';
import 'savings_goal_model.dart';
import 'savings_repository.dart';

class SavingsNotifier extends AsyncNotifier<List<SavingsGoalModel>> {
  late SavingsRepository _repository;

  @override
  FutureOr<List<SavingsGoalModel>> build() async {
    _repository = ref.watch(savingsRepositoryProvider);
    ref.watch(activeSpaceIdProvider);
    final goals = await _repository.fetchGoals(
      spaceId: ref.read(activeSpaceIdProvider),
    );
    unawaited(_notifyNearDeadlineIfNeeded(goals));
    return goals;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final goals = await _repository.fetchGoals(
        spaceId: ref.read(activeSpaceIdProvider),
      );
      unawaited(_notifyNearDeadlineIfNeeded(goals));
      return goals;
    });
  }

  Future<void> createGoal(SavingsGoalModel goal) async {
    await _repository.createGoal(
      goal,
      spaceId: ref.read(activeSpaceIdProvider),
    );
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'create_goal',
          description: 'Membuat savings goal ${goal.name}',
          metadata: {'target_amount': goal.targetAmount},
        );
    await _refreshAll();
  }

  Future<void> updateGoal(SavingsGoalModel goal) async {
    await _repository.updateGoal(
      goal,
      spaceId: ref.read(activeSpaceIdProvider),
    );
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'update_goal',
          description: 'Memperbarui savings goal ${goal.name}',
          metadata: {'goal_id': goal.id},
        );
    await _refreshAll();
  }

  Future<void> deleteGoal(String goalId) async {
    await _repository.deleteGoal(
      goalId,
      spaceId: ref.read(activeSpaceIdProvider),
    );
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'delete_goal',
          description: 'Menghapus savings goal',
          metadata: {'goal_id': goalId},
        );
    await _refreshAll();
  }

  Future<void> topUp({
    required String goalId,
    required double amount,
    required String accountId,
    String? note,
  }) async {
    await _repository.topUp(
      goalId,
      amount,
      accountId,
      note,
      ref.read(activeSpaceIdProvider),
    );
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'topup_goal',
          description: 'Top up savings goal',
          metadata: {'goal_id': goalId, 'amount': amount},
        );
    await _refreshAll();
  }

  Future<void> withdraw({
    required String goalId,
    required double amount,
    required String accountId,
    String? note,
  }) async {
    await _repository.withdraw(
      goalId,
      amount,
      accountId,
      note,
      ref.read(activeSpaceIdProvider),
    );
    await ref
        .read(activityLogServiceProvider)
        .log(
          action: 'withdraw_goal',
          description: 'Tarik dana savings goal',
          metadata: {'goal_id': goalId, 'amount': amount},
        );
    await _refreshAll();
  }

  Future<List<SavingsDepositModel>> fetchDeposits(String goalId) {
    return _repository.fetchDeposits(
      goalId,
      spaceId: ref.read(activeSpaceIdProvider),
    );
  }

  Future<void> _refreshAll() async {
    final goals = await _repository.fetchGoals(
      spaceId: ref.read(activeSpaceIdProvider),
    );
    state = AsyncData(goals);
    ref.invalidate(accountBalancesProvider);
    ref.invalidate(transactionNotifierProvider);
    unawaited(_notifyNearDeadlineIfNeeded(goals));
  }

  Future<void> _notifyNearDeadlineIfNeeded(List<SavingsGoalModel> goals) async {
    for (final goal in goals) {
      if (goal.isCompleted) continue;
      final days = goal.daysRemaining;
      if (days < 0 || days > 7) continue;
      if (goal.progress >= 0.8) continue;
      await NotificationService.showSavingsGoalReminder(
        goalId: goal.id,
        goalName: goal.name,
        progressPct: goal.progress * 100,
        daysRemaining: days,
      );
    }
  }
}

final savingsNotifierProvider =
    AsyncNotifierProvider<SavingsNotifier, List<SavingsGoalModel>>(() {
      return SavingsNotifier();
    });

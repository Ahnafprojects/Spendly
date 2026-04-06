import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_notifier.dart';
import '../spaces/space_notifier.dart';
import 'analytics_repository.dart';

class AnalyticsState {
  final String period;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final DateTime selectedMonth;
  final double totalIncome;
  final double totalExpense;
  final double netSaving;
  final List<CategoryMetric> categoryMetrics;
  final List<BarMetric> barMetrics;
  final List<UserContributionMetric> userContributions;

  const AnalyticsState({
    required this.period,
    required this.rangeStart,
    required this.rangeEnd,
    required this.selectedMonth,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSaving,
    required this.categoryMetrics,
    required this.barMetrics,
    this.userContributions = const [],
  });
}

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  late AnalyticsRepository _repository;
  DateTime? _lastFetch;
  String _currentPeriod = 'Weekly';
  DateTime _selectedMonth = _monthStart(DateTime.now());
  AnalyticsState? _cachedState;
  String? _cachedAccountId;
  String? _cachedSpaceId;
  DateTime? _cacheMonth;

  @override
  FutureOr<AnalyticsState> build() async {
    _repository = ref.watch(analyticsRepositoryProvider);
    ref.watch(activeAccountIdProvider);
    ref.watch(activeSpaceIdProvider);
    return _fetchData(_currentPeriod);
  }

  Future<void> changePeriod(String newPeriod) async {
    if (_currentPeriod == newPeriod) return;
    _currentPeriod = newPeriod;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchData(newPeriod, forceRefresh: true),
    );
  }

  Future<void> changeMonth(int delta) async {
    final current = _selectedMonth;
    final candidate = DateTime(current.year, current.month + delta, 1);
    final thisMonth = _monthStart(DateTime.now());
    if (candidate.isAfter(thisMonth)) return;
    _selectedMonth = candidate;
    if (_currentPeriod != 'Monthly') {
      _currentPeriod = 'Monthly';
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchData('Monthly', forceRefresh: true),
    );
  }

  Future<void> refreshCurrentPeriod() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchData(_currentPeriod, forceRefresh: true),
    );
  }

  Future<AnalyticsState> _fetchData(
    String period, {
    bool forceRefresh = false,
  }) async {
    final activeAccountId = ref.read(activeAccountIdProvider);
    final activeSpaceId = ref.read(activeSpaceIdProvider);
    final selectedMonth = _selectedMonth;

    if (!forceRefresh &&
        _lastFetch != null &&
        _cachedState != null &&
        _cachedState!.period == period &&
        _cachedAccountId == activeAccountId &&
        _cachedSpaceId == activeSpaceId &&
        _cacheMonth == selectedMonth) {
      final difference = DateTime.now().difference(_lastFetch!);
      if (difference.inMinutes < 5) return _cachedState!;
    }

    final now = DateTime.now();
    DateTime start;
    DateTime end;

    if (period == 'Weekly') {
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
    } else if (period == 'Monthly') {
      final firstDay = _monthStart(selectedMonth);
      final nextMonth = DateTime(firstDay.year, firstDay.month + 1, 1);
      final lastDay = nextMonth.subtract(const Duration(seconds: 1));
      start = firstDay;
      end = _monthStart(now) == firstDay
          ? DateTime(now.year, now.month, now.day, 23, 59, 59)
          : lastDay;
    } else {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, 12, 31, 23, 59, 59);
      if (end.isAfter(now)) {
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }
    }

    final transactions = await _repository.fetchTransactionsByDateRange(
      start,
      end,
      accountId: activeAccountId,
      spaceId: activeSpaceId,
    );

    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
      final isIncome =
          tx.type == 'income' ||
          (tx.type == 'transfer' && tx.transferDirection == 'in');
      final isExpense =
          tx.type == 'expense' ||
          (tx.type == 'transfer' && tx.transferDirection == 'out');
      if (isIncome) income += tx.amount;
      if (isExpense) expense += tx.amount;
    }

    final categoryMetrics = _repository.getCategoryBreakdown(transactions);
    final userContributions = activeSpaceId != null
        ? _repository.getUserContributions(transactions)
        : <UserContributionMetric>[];
    final newState = AnalyticsState(
      period: period,
      rangeStart: start,
      rangeEnd: end,
      selectedMonth: selectedMonth,
      totalIncome: income,
      totalExpense: expense,
      netSaving: income - expense,
      categoryMetrics: categoryMetrics,
      barMetrics: _repository.getBarMetrics(
        transactions,
        period,
        monthRef: selectedMonth,
        rangeStart: start,
      ),
      userContributions: userContributions,
    );

    _lastFetch = DateTime.now();
    _cachedState = newState;
    _cachedAccountId = activeAccountId;
    _cachedSpaceId = activeSpaceId;
    _cacheMonth = selectedMonth;
    return newState;
  }

  static DateTime _monthStart(DateTime value) {
    return DateTime(value.year, value.month, 1);
  }
}

final analyticsNotifierProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(() {
      return AnalyticsNotifier();
    });

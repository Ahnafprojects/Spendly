import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_repository.dart';

// State yang menampung semua data Analytics
class AnalyticsState {
  final String period;
  final double totalIncome;
  final double totalExpense;
  final double netSaving;
  final List<CategoryMetric> categoryMetrics;
  final List<BarMetric> barMetrics;

  AnalyticsState({
    required this.period,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSaving,
    required this.categoryMetrics,
    required this.barMetrics,
  });
}

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  late AnalyticsRepository _repository;
  DateTime? _lastFetch;
  String _currentPeriod = 'Weekly'; // Default
  AnalyticsState? _cachedState;

  @override
  FutureOr<AnalyticsState> build() async {
    _repository = ref.watch(analyticsRepositoryProvider);
    return _fetchData(_currentPeriod);
  }

  Future<void> changePeriod(String newPeriod) async {
    if (_currentPeriod == newPeriod) return;
    _currentPeriod = newPeriod;
    
    // Set loading sementara mengambil data baru
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData(newPeriod, forceRefresh: true));
  }

  Future<void> refreshCurrentPeriod() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _fetchData(_currentPeriod, forceRefresh: true),
    );
  }

  Future<AnalyticsState> _fetchData(String period, {bool forceRefresh = false}) async {
    // CACHE LOGIC: Gunakan cache jika belum lewat 5 menit dan tidak di-force
    if (!forceRefresh && _lastFetch != null && _cachedState != null && _cachedState!.period == period) {
      final difference = DateTime.now().difference(_lastFetch!);
      if (difference.inMinutes < 5) {
        return _cachedState!;
      }
    }

    // Menentukan rentang tanggal berdasarkan period
    final now = DateTime.now();
    DateTime start = now.subtract(const Duration(days: 7));
    if (period == 'Monthly') start = DateTime(now.year, now.month - 1, now.day);
    if (period == 'Yearly') start = DateTime(now.year - 1, now.month, now.day);

    // Fetch dari Supabase
    final transactions = await _repository.fetchTransactionsByDateRange(start, now);

    // Hitung Summary
    double income = 0;
    double expense = 0;
    for (var tx in transactions) {
      if (tx.type == 'income') income += tx.amount;
      if (tx.type == 'expense') expense += tx.amount;
    }

    // Susun State
    final categoryMetrics = _repository.getCategoryBreakdown(transactions);
    final newState = AnalyticsState(
      period: period,
      totalIncome: income,
      totalExpense: expense,
      netSaving: income - expense,
      categoryMetrics: categoryMetrics,
      barMetrics: _repository.getBarMetrics(transactions, period),
    );

    _lastFetch = DateTime.now();
    _cachedState = newState;
    return newState;
  }
}

// Gunakan keepAlive agar cache 5 menit tetap berlaku meski user pindah tab
final analyticsNotifierProvider = AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(() {
  return AnalyticsNotifier();
});

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/constants/transaction_categories.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/services/currency_settings.dart';
import '../../shared/services/env_config.dart';
import '../../shared/services/offline_store.dart';
import '../../shared/services/notification_service.dart';
import '../analytics/analytics_repository.dart';
import '../budget/budget_repository.dart';
import '../budget/models/budget_usage_model.dart';
import 'insights_model.dart';

class InsightsService {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;
  final AnalyticsRepository _analyticsRepository;
  final BudgetRepository _budgetRepository;

  InsightsService({
    SupabaseClient? supabase,
    required OfflineStore offlineStore,
    required AnalyticsRepository analyticsRepository,
    required BudgetRepository budgetRepository,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _offlineStore = offlineStore,
       _analyticsRepository = analyticsRepository,
       _budgetRepository = budgetRepository;

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

  Future<InsightsBundle> loadInsights({
    String? accountId,
    String? spaceId,
    bool forceRefresh = false,
  }) async {
    final userId = await _resolveUserId();
    final cacheKey = _cacheKey(userId, accountId: accountId, spaceId: spaceId);
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString(cacheKey);
    final now = DateTime.now();

    if (!forceRefresh && cachedRaw != null && cachedRaw.isNotEmpty) {
      final cached = InsightsBundle.decode(cachedRaw);
      if (now.difference(cached.updatedAt) < const Duration(hours: 8)) {
        await NotificationService.maybeShowWeeklyDigest(cached);
        return cached;
      }
    }

    final snapshot = await _buildSnapshot(
      userId,
      accountId: accountId,
      spaceId: spaceId,
    );

    InsightsBundle generated;
    try {
      generated = await _generateWithGroq(snapshot);
    } catch (_) {
      generated = _generateHeuristic(snapshot);
    }

    final history = await _appendHistory(
      cacheKey: '${cacheKey}_history',
      latest: generated.mainInsight,
    );
    generated = InsightsBundle(
      mainInsight: generated.mainInsight,
      weeklyFindings: generated.weeklyFindings,
      personalTips: generated.personalTips,
      prediction: generated.prediction,
      supportingFacts: generated.supportingFacts,
      history: history,
      updatedAt: generated.updatedAt,
      periodLabel: generated.periodLabel,
      source: generated.source,
    );

    await prefs.setString(cacheKey, generated.encode());
    await NotificationService.maybeShowWeeklyDigest(generated);
    return generated;
  }

  Future<void> invalidateCache({String? accountId, String? spaceId}) async {
    final userId = await _resolveUserId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
      _cacheKey(userId, accountId: accountId, spaceId: spaceId),
    );
  }

  Future<List<InsightItem>> _appendHistory({
    required String cacheKey,
    required InsightItem latest,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    final existing = <InsightItem>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          existing.addAll(
            decoded.whereType<Map>().map(
              (item) => InsightItem.fromJson(Map<String, dynamic>.from(item)),
            ),
          );
        }
      } catch (_) {}
    }

    final merged = <InsightItem>[latest];
    for (final item in existing) {
      if (item.title == latest.title &&
          item.description == latest.description) {
        continue;
      }
      merged.add(item);
      if (merged.length >= 6) break;
    }

    await prefs.setString(
      cacheKey,
      jsonEncode(merged.map((item) => item.toJson()).toList()),
    );
    return merged;
  }

  String _cacheKey(String userId, {String? accountId, String? spaceId}) {
    final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
    final scope = [
      userId,
      accountId ?? 'all',
      spaceId ?? 'personal',
      monthKey,
    ].join('_');
    return 'ai_insights_$scope';
  }

  Future<_InsightsSnapshot> _buildSnapshot(
    String userId, {
    String? accountId,
    String? spaceId,
  }) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);
    final previousMonthEnd = monthStart.subtract(const Duration(days: 1));
    final thirtyDaysAgo = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final fourteenDaysAgo = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 13));
    final monthEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final currentMonthTx = await _analyticsRepository
        .fetchTransactionsByDateRange(
          monthStart,
          monthEnd,
          accountId: accountId,
          spaceId: spaceId,
        );
    final previousMonthTx = await _analyticsRepository
        .fetchTransactionsByDateRange(
          previousMonthStart,
          DateTime(
            previousMonthEnd.year,
            previousMonthEnd.month,
            previousMonthEnd.day,
            23,
            59,
            59,
          ),
          accountId: accountId,
          spaceId: spaceId,
        );
    final thirtyDayTx = await _analyticsRepository.fetchTransactionsByDateRange(
      thirtyDaysAgo,
      monthEnd,
      accountId: accountId,
      spaceId: spaceId,
    );
    final fourteenDayTx = await _analyticsRepository
        .fetchTransactionsByDateRange(
          fourteenDaysAgo,
          monthEnd,
          accountId: accountId,
          spaceId: spaceId,
        );
    final budgetUsage = await _budgetRepository.fetchBudgetUsage(
      monthStart,
      accountId: accountId,
      spaceId: spaceId,
    );

    final currentSummary = _summaryFor(currentMonthTx);
    final previousSummary = _summaryFor(previousMonthTx);
    final categoryTotals = _analyticsRepository
        .getCategoryBreakdown(thirtyDayTx)
        .take(6)
        .toList();
    final dailyTotals = _dailyTotals(fourteenDayTx, fourteenDaysAgo, now);
    final weekendShare = _weekendShare(thirtyDayTx);
    final prediction = _projectMonthExpense(currentSummary.expense, now);

    return _InsightsSnapshot(
      userId: userId,
      periodLabel: DateFormat('MMMM yyyy', 'id_ID').format(now),
      generatedAt: now,
      currentMonth: currentSummary,
      previousMonth: previousSummary,
      thirtyDayCategoryTotals: categoryTotals,
      dailyTotals14Days: dailyTotals,
      budgetUsage: budgetUsage,
      currentMonthTransactions: currentMonthTx,
      weekendExpenseShare: weekendShare,
      predictedMonthExpense: prediction,
    );
  }

  _MonthSummary _summaryFor(List<TransactionModel> transactions) {
    var income = 0.0;
    var expense = 0.0;
    for (final tx in transactions) {
      if (tx.type == 'income' ||
          (tx.type == 'transfer' && tx.transferDirection == 'in')) {
        income += tx.amount;
      } else if (tx.type == 'expense' ||
          (tx.type == 'transfer' && tx.transferDirection == 'out')) {
        expense += tx.amount;
      }
    }
    return _MonthSummary(
      income: income,
      expense: expense,
      savings: income - expense,
    );
  }

  List<Map<String, dynamic>> _dailyTotals(
    List<TransactionModel> transactions,
    DateTime start,
    DateTime end,
  ) {
    final normalized = <String, Map<String, double>>{};
    for (final tx in transactions) {
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      final bucket = normalized.putIfAbsent(
        key,
        () => {'income': 0, 'expense': 0},
      );
      if (tx.type == 'income' ||
          (tx.type == 'transfer' && tx.transferDirection == 'in')) {
        bucket['income'] = (bucket['income'] ?? 0) + tx.amount;
      } else if (tx.type == 'expense' ||
          (tx.type == 'transfer' && tx.transferDirection == 'out')) {
        bucket['expense'] = (bucket['expense'] ?? 0) + tx.amount;
      }
    }

    return List.generate(end.difference(start).inDays + 1, (index) {
      final day = DateTime(start.year, start.month, start.day + index);
      final key = DateFormat('yyyy-MM-dd').format(day);
      final bucket = normalized[key] ?? const {'income': 0, 'expense': 0};
      return {
        'day': key,
        'income': bucket['income'] ?? 0,
        'expense': bucket['expense'] ?? 0,
      };
    });
  }

  double _weekendShare(List<TransactionModel> transactions) {
    var weekend = 0.0;
    var total = 0.0;
    for (final tx in transactions) {
      final isExpense =
          tx.type == 'expense' ||
          (tx.type == 'transfer' && tx.transferDirection == 'out');
      if (!isExpense) continue;
      total += tx.amount;
      if (tx.date.weekday == DateTime.saturday ||
          tx.date.weekday == DateTime.sunday) {
        weekend += tx.amount;
      }
    }
    if (total <= 0) return 0;
    return weekend / total;
  }

  double _projectMonthExpense(double currentExpense, DateTime now) {
    final daysElapsed = now.day.clamp(1, 31);
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    return currentExpense / daysElapsed * totalDays;
  }

  Future<InsightsBundle> _generateWithGroq(_InsightsSnapshot snapshot) async {
    final groqApiKey = EnvConfig.get('GROQ_API_KEY');
    final groqModel = EnvConfig.get(
      'GROQ_MODEL',
      fallback: 'openai/gpt-oss-120b',
    );
    final groqBaseUrl = EnvConfig.get(
      'GROQ_BASE_URL',
      fallback: 'https://api.groq.com/openai/v1/chat/completions',
    );
    if (groqApiKey.trim().isEmpty) {
      throw Exception('Missing GROQ_API_KEY');
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(groqBaseUrl));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $groqApiKey',
      );
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'model': groqModel,
            'temperature': 0.4,
            'max_tokens': 1600,
            'response_format': {'type': 'json_object'},
            'messages': [
              {
                'role': 'system',
                'content':
                    'Kamu adalah analis keuangan personal untuk app Spendly. '
                    'Berikan insight spesifik berbasis data transaksi user, bukan saran generik. '
                    'Fokus pada perubahan bulan ini vs bulan lalu, kategori terbesar, pola 14 hari, penggunaan budget, dan prediksi akhir bulan. '
                    'Gunakan bahasa Indonesia yang ringkas, jelas, actionable, dan tidak menghakimi. '
                    'Balas hanya JSON valid dengan shape: '
                    '{"main_insight":{"title":"","description":"","kind":"warning|good|tip|trend","category":""},'
                    '"weekly_findings":[{"title":"","description":"","kind":"warning|good|tip|trend","category":""}],'
                    '"personal_tips":["","",""],'
                    '"prediction":"",'
                    '"supporting_facts":[{"label":"","value":""}]}.',
              },
              {'role': 'user', 'content': jsonEncode(snapshot.toPromptJson())},
            ],
          }),
        ),
      );

      final response = await request.close();
      final raw = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Groq API error ${response.statusCode}: $raw');
      }

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final choices = decoded['choices'] as List?;
      final content =
          (((choices?.first as Map?)?['message'] as Map?)?['content'])
              ?.toString();
      if (content == null || content.trim().isEmpty) {
        throw const FormatException('AI response content empty');
      }
      return _parseAiBundle(content, snapshot.periodLabel);
    } finally {
      client.close(force: true);
    }
  }

  InsightsBundle _parseAiBundle(String content, String periodLabel) {
    final cleaned = content
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final decoded = Map<String, dynamic>.from(jsonDecode(cleaned) as Map);
    final mainInsight = InsightItem.fromJson(
      Map<String, dynamic>.from(decoded['main_insight'] as Map),
    );
    final findings = ((decoded['weekly_findings'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => InsightItem.fromJson(Map<String, dynamic>.from(item)))
        .take(4)
        .toList();
    final tips = ((decoded['personal_tips'] as List?) ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList();
    final prediction = (decoded['prediction'] ?? '').toString().trim();
    final supportingFacts = ((decoded['supporting_facts'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => SupportingFact.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.label.isNotEmpty && item.value.isNotEmpty)
        .take(4)
        .toList();

    return InsightsBundle(
      mainInsight: mainInsight,
      weeklyFindings: findings.isEmpty ? [mainInsight] : findings,
      personalTips: tips.isEmpty
          ? ['Kurangi kategori dengan lonjakan terbesar minggu ini.']
          : tips,
      prediction: prediction.isEmpty
          ? 'Belum cukup data untuk membuat prediksi yang tajam.'
          : prediction,
      supportingFacts: supportingFacts,
      history: const [],
      updatedAt: DateTime.now(),
      periodLabel: periodLabel,
      source: 'groq',
    );
  }

  InsightsBundle _generateHeuristic(_InsightsSnapshot snapshot) {
    final prevExpense = snapshot.previousMonth.expense;
    final expenseChangePct = prevExpense <= 0
        ? 0.0
        : ((snapshot.currentMonth.expense - prevExpense) / prevExpense) * 100;
    final topCategory = snapshot.thirtyDayCategoryTotals.isEmpty
        ? null
        : snapshot.thirtyDayCategoryTotals.first;
    final hottestBudget = snapshot.budgetUsage.isEmpty
        ? null
        : snapshot.budgetUsage.first;
    final main = _buildMainInsight(
      snapshot,
      expenseChangePct: expenseChangePct,
      topCategory: topCategory,
      hottestBudget: hottestBudget,
    );

    final findings = <InsightItem>[
      main,
      if (topCategory != null)
        InsightItem(
          title:
              '${localizeCategory(topCategory.category)} jadi kategori utama',
          description:
              'Dalam 30 hari terakhir, kategori ini menyumbang ${_percentOf(topCategory.amount, snapshot.currentMonth.expense)} dari total pengeluaran.',
          kind: InsightKind.trend,
          category: topCategory.category,
        ),
      if (snapshot.weekendExpenseShare >= 0.38)
        InsightItem(
          title: 'Pengeluaran naik saat akhir pekan',
          description:
              '${(snapshot.weekendExpenseShare * 100).toStringAsFixed(0)}% pengeluaran 30 hari terakhir terjadi di Sabtu-Minggu.',
          kind: InsightKind.warning,
          category: topCategory?.category ?? 'Lainnya',
        ),
      if (hottestBudget != null)
        InsightItem(
          title: _budgetTitle(hottestBudget),
          description:
              'Budget ${localizeCategory(hottestBudget.category)} sudah terpakai ${hottestBudget.usagePct.toStringAsFixed(0)}% bulan ini.',
          kind: hottestBudget.isOver ? InsightKind.warning : InsightKind.tip,
          category: hottestBudget.category,
        ),
      if (snapshot.currentMonth.savings > 0 &&
          snapshot.currentMonth.expense <= snapshot.previousMonth.expense)
        InsightItem(
          title: 'Arus kas membaik',
          description:
              'Sisa bersih bulan ini ${CurrencySettings.format(snapshot.currentMonth.savings)} dan pengeluaran tidak lebih tinggi dari bulan lalu.',
          kind: InsightKind.good,
          category: 'Lainnya',
        ),
    ].take(4).toList();

    final tips = _buildTips(
      snapshot,
      topCategory: topCategory,
      hottestBudget: hottestBudget,
    );
    final prediction = _buildPrediction(snapshot, hottestBudget: hottestBudget);
    final supportingFacts = _buildSupportingFacts(
      snapshot,
      topCategory: topCategory,
      hottestBudget: hottestBudget,
      expenseChangePct: expenseChangePct,
    );

    return InsightsBundle(
      mainInsight: main,
      weeklyFindings: findings,
      personalTips: tips,
      prediction: prediction,
      supportingFacts: supportingFacts,
      history: const [],
      updatedAt: DateTime.now(),
      periodLabel: snapshot.periodLabel,
      source: 'heuristic',
    );
  }

  InsightItem _buildMainInsight(
    _InsightsSnapshot snapshot, {
    required double expenseChangePct,
    required CategoryMetric? topCategory,
    required BudgetUsageModel? hottestBudget,
  }) {
    if (hottestBudget != null && hottestBudget.isOver) {
      return InsightItem(
        title:
            'Budget ${localizeCategory(hottestBudget.category)} sudah lewat batas',
        description:
            'Kamu overspend ${CurrencySettings.format(hottestBudget.spentAmount - hottestBudget.limitAmount)} di kategori ini. Fokus pangkas pengeluaran kecil berulang mulai minggu ini.',
        kind: InsightKind.warning,
        category: hottestBudget.category,
      );
    }

    if (expenseChangePct >= 15 && topCategory != null) {
      return InsightItem(
        title:
            'Pengeluaran naik ${expenseChangePct.toStringAsFixed(0)}% dari bulan lalu',
        description:
            '${localizeCategory(topCategory.category)} jadi pendorong utama kenaikan. Total pengeluaran bulan ini sudah ${CurrencySettings.format(snapshot.currentMonth.expense)}.',
        kind: InsightKind.warning,
        category: topCategory.category,
      );
    }

    if (snapshot.currentMonth.savings > 0 &&
        snapshot.currentMonth.expense < snapshot.previousMonth.expense) {
      return InsightItem(
        title: 'Pengeluaran lebih terkontrol bulan ini',
        description:
            'Kamu menekan pengeluaran dibanding bulan lalu dan masih menyisakan arus kas positif ${CurrencySettings.format(snapshot.currentMonth.savings)}.',
        kind: InsightKind.good,
        category: topCategory?.category ?? 'Lainnya',
      );
    }

    if (topCategory != null) {
      return InsightItem(
        title:
            '${localizeCategory(topCategory.category)} paling dominan bulan ini',
        description:
            'Kategori ini sudah menyerap ${CurrencySettings.format(topCategory.amount)}. Cocok dijadikan fokus evaluasi utama minggu ini.',
        kind: InsightKind.trend,
        category: topCategory.category,
      );
    }

    return const InsightItem(
      title: 'Belum cukup pola pengeluaran',
      description:
          'Tambahkan lebih banyak transaksi supaya insight bisa lebih personal dan tajam.',
      kind: InsightKind.tip,
      category: 'Lainnya',
    );
  }

  String _percentOf(double amount, double total) {
    if (amount <= 0 || total <= 0) return '0%';
    return '${((amount / total) * 100).toStringAsFixed(0)}%';
  }

  String _budgetTitle(BudgetUsageModel budget) {
    if (budget.isOver) {
      return 'Budget ${localizeCategory(budget.category)} terlewati';
    }
    if (budget.usagePct >= 85) {
      return 'Budget ${localizeCategory(budget.category)} hampir habis';
    }
    return 'Budget ${localizeCategory(budget.category)} perlu dipantau';
  }

  List<String> _buildTips(
    _InsightsSnapshot snapshot, {
    required CategoryMetric? topCategory,
    required BudgetUsageModel? hottestBudget,
  }) {
    final tips = <String>[];
    if (topCategory != null) {
      tips.add(
        'Batasi ${localizeCategory(topCategory.category)} dengan target mingguan, bukan hanya target bulanan.',
      );
    }
    if (snapshot.weekendExpenseShare >= 0.38) {
      tips.add(
        'Siapkan anggaran khusus akhir pekan agar pengeluaran Sabtu-Minggu tidak bocor ke kategori lain.',
      );
    }
    if (hottestBudget != null) {
      tips.add(
        'Cek transaksi kecil berulang di ${localizeCategory(hottestBudget.category)}. Biasanya kebocoran terbesar datang dari frekuensi, bukan satu transaksi besar.',
      );
    }
    if (snapshot.currentMonth.income > 0 &&
        snapshot.currentMonth.savings <= 0) {
      tips.add(
        'Sisihkan nominal tabungan tetap di awal bulan agar sisa kas tidak habis mengikuti pengeluaran harian.',
      );
    }
    if (tips.isEmpty) {
      tips.add(
        'Pertahankan pencatatan harian. Konsistensi input transaksi akan membuat insight berikutnya jauh lebih akurat.',
      );
    }
    return tips.take(4).toList();
  }

  String _buildPrediction(
    _InsightsSnapshot snapshot, {
    required BudgetUsageModel? hottestBudget,
  }) {
    final projected = snapshot.predictedMonthExpense;
    final currentExpense = snapshot.currentMonth.expense;
    final projectedDelta = projected - currentExpense;

    if (hottestBudget != null && projectedDelta > 0) {
      final categoryProjection =
          hottestBudget.spentAmount +
          ((hottestBudget.spentAmount / DateTime.now().day) *
              (DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day -
                  DateTime.now().day));
      final overBy = categoryProjection - hottestBudget.limitAmount;
      if (overBy > 0) {
        return 'Dengan pola saat ini, ${localizeCategory(hottestBudget.category)} berpotensi melewati budget sekitar ${CurrencySettings.format(overBy)} sebelum akhir bulan.';
      }
    }

    if (projected > currentExpense) {
      return 'Dengan ritme sekarang, total pengeluaran bulan ini diproyeksikan menyentuh ${CurrencySettings.format(projected)}.';
    }

    return 'Pola pengeluaran saat ini masih cukup stabil untuk bertahan di sekitar ${CurrencySettings.format(currentExpense)} sampai akhir bulan.';
  }

  List<SupportingFact> _buildSupportingFacts(
    _InsightsSnapshot snapshot, {
    required CategoryMetric? topCategory,
    required BudgetUsageModel? hottestBudget,
    required double expenseChangePct,
  }) {
    final facts = <SupportingFact>[
      SupportingFact(
        label: 'Pengeluaran bulan ini',
        value: CurrencySettings.format(snapshot.currentMonth.expense),
      ),
      SupportingFact(
        label: 'Vs bulan lalu',
        value:
            '${expenseChangePct >= 0 ? '+' : ''}${expenseChangePct.toStringAsFixed(0)}%',
      ),
      SupportingFact(
        label: 'Porsi akhir pekan',
        value: '${(snapshot.weekendExpenseShare * 100).toStringAsFixed(0)}%',
      ),
    ];
    if (topCategory != null) {
      facts.add(
        SupportingFact(
          label: 'Kategori terbesar',
          value:
              '${localizeCategory(topCategory.category)} • ${CurrencySettings.format(topCategory.amount)}',
        ),
      );
    }
    if (hottestBudget != null) {
      facts.add(
        SupportingFact(
          label: 'Budget terpanas',
          value:
              '${localizeCategory(hottestBudget.category)} • ${hottestBudget.usagePct.toStringAsFixed(0)}%',
        ),
      );
    }
    return facts.take(4).toList();
  }
}

class _InsightsSnapshot {
  final String userId;
  final String periodLabel;
  final DateTime generatedAt;
  final _MonthSummary currentMonth;
  final _MonthSummary previousMonth;
  final List<CategoryMetric> thirtyDayCategoryTotals;
  final List<Map<String, dynamic>> dailyTotals14Days;
  final List<BudgetUsageModel> budgetUsage;
  final List<TransactionModel> currentMonthTransactions;
  final double weekendExpenseShare;
  final double predictedMonthExpense;

  const _InsightsSnapshot({
    required this.userId,
    required this.periodLabel,
    required this.generatedAt,
    required this.currentMonth,
    required this.previousMonth,
    required this.thirtyDayCategoryTotals,
    required this.dailyTotals14Days,
    required this.budgetUsage,
    required this.currentMonthTransactions,
    required this.weekendExpenseShare,
    required this.predictedMonthExpense,
  });

  Map<String, dynamic> toPromptJson() {
    return {
      'user_id': userId,
      'period': periodLabel,
      'generated_at': generatedAt.toIso8601String(),
      'currency': 'IDR',
      'current_month_summary': currentMonth.toJson(),
      'previous_month_summary': previousMonth.toJson(),
      'top_categories_30d': thirtyDayCategoryTotals
          .map(
            (item) => {
              'category': item.category,
              'localized_category': localizeCategory(item.category),
              'amount': item.amount,
            },
          )
          .toList(),
      'daily_totals_14d': dailyTotals14Days,
      'budget_usage': budgetUsage
          .map(
            (item) => {
              'category': item.category,
              'localized_category': localizeCategory(item.category),
              'limit_amount': item.limitAmount,
              'spent_amount': item.spentAmount,
              'remaining': item.remaining,
              'usage_pct': item.usagePct,
              'is_over': item.isOver,
            },
          )
          .toList(),
      'weekend_expense_share': weekendExpenseShare,
      'predicted_month_expense': predictedMonthExpense,
      'recent_transactions': currentMonthTransactions
          .take(12)
          .map(
            (tx) => {
              'date': DateFormat('yyyy-MM-dd').format(tx.date),
              'type': tx.type,
              'category': tx.category,
              'amount': tx.amount,
              'note': tx.note,
            },
          )
          .toList(),
    };
  }
}

class _MonthSummary {
  final double income;
  final double expense;
  final double savings;

  const _MonthSummary({
    required this.income,
    required this.expense,
    required this.savings,
  });

  Map<String, dynamic> toJson() {
    return {'income': income, 'expense': expense, 'savings': savings};
  }
}

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService(
    offlineStore: ref.watch(offlineStoreProvider),
    analyticsRepository: ref.watch(analyticsRepositoryProvider),
    budgetRepository: ref.watch(budgetRepositoryProvider),
  );
});

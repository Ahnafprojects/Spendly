import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../analytics_notifier.dart';
import '../analytics_repository.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _touchedPieIndex = -1;
  String _t(String id, String en) => AppText.t(id: id, en: en);

  String _periodLabel(String key) {
    if (key == 'Weekly') return _t('Mingguan', 'Weekly');
    if (key == 'Monthly') return _t('Bulanan', 'Monthly');
    if (key == 'Yearly') return _t('Tahunan', 'Yearly');
    return key;
  }

  String _rangeLabel(AnalyticsState data) {
    final locale = LanguageSettings.current.locale.toString();
    final start = DateFormat('dd MMM yyyy', locale).format(data.rangeStart);
    final end = DateFormat('dd MMM yyyy', locale).format(data.rangeEnd);
    return '$start - $end';
  }

  String _monthLabel(DateTime month) {
    return DateFormat(
      'MMMM yyyy',
      LanguageSettings.current.locale.toString(),
    ).format(month);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);
    final analyticsState = ref.watch(analyticsNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090B14)
          : const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          _t('Analitik', 'Analytics'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1E2A),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: analyticsState.when(
          data: _buildContent,
          loading: _buildShimmer,
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                '${_t('Gagal memuat analitik', 'Failed to load analytics')}:\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AnalyticsState data) {
    final hasAnyData =
        data.totalIncome > 0 ||
        data.totalExpense > 0 ||
        data.categoryMetrics.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(analyticsNotifierProvider.notifier).refreshCurrentPeriod(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildPeriodSelector(data.period),
          if (data.period == 'Monthly') ...[
            const SizedBox(height: 10),
            _buildMonthNavigator(data.selectedMonth),
          ],
          const SizedBox(height: 10),
          _buildRangeInfo(data),
          const SizedBox(height: 18),
          _buildHeroSummary(data),
          const SizedBox(height: 18),
          _buildMetricsRow(data),
          const SizedBox(height: 22),
          _buildSectionTitle(_t('Tren Arus Kas', 'Cashflow Trend')),
          const SizedBox(height: 12),
          _buildBarChartCard(data.barMetrics),
          const SizedBox(height: 22),
          _buildSectionTitle(_t('Rincian Pengeluaran', 'Spending Breakdown')),
          const SizedBox(height: 12),
          if (hasAnyData && data.categoryMetrics.isNotEmpty)
            _buildPieChartCard(data.categoryMetrics)
          else
            _buildEmptyState(),
          const SizedBox(height: 22),
          _buildSectionTitle(_t('Pengeluaran Terbesar', 'Top Spending')),
          const SizedBox(height: 12),
          _buildTopSpendingCard(data.categoryMetrics, data.totalExpense),
          if (data.userContributions.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildSectionTitle(
              _t('Kontribusi Anggota', 'Member Contributions'),
            ),
            const SizedBox(height: 12),
            _buildMemberContributionsCard(data.userContributions),
          ],
        ],
      ),
    );
  }

  Widget _buildRangeInfo(AnalyticsState data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 16,
            color: isDark ? Colors.white60 : const Color(0xFF5B6275),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _rangeLabel(data),
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF5B6275),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1A1E2A),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPeriodSelector(String currentPeriod) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = ['Weekly', 'Monthly', 'Yearly'];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Row(
        children: periods.map((period) {
          final selected = period == currentPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref
                  .read(analyticsNotifierProvider.notifier)
                  .changePeriod(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF4F6EF7)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _periodLabel(period),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF5B6275)),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthNavigator(DateTime selectedMonth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonth = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == currentMonth.year &&
        selectedMonth.month == currentMonth.month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
            onPressed: () =>
                ref.read(analyticsNotifierProvider.notifier).changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              _monthLabel(selectedMonth),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
            onPressed: isCurrentMonth
                ? null
                : () => ref
                      .read(analyticsNotifierProvider.notifier)
                      .changeMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummary(AnalyticsState data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = data.netSaving >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Tabungan Bersih', 'Net Saving'),
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF5B6275),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencySettings.format(data.netSaving),
            style: TextStyle(
              color: isPositive
                  ? const Color(0xFF00D4AA)
                  : const Color(0xFFFF5A6E),
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 16,
                color: isDark ? Colors.white54 : const Color(0xFF6D7892),
              ),
              const SizedBox(width: 6),
              Text(
                isPositive
                    ? _t(
                        'Keuangan kamu masih sehat.',
                        'Your finances are in good shape.',
                      )
                    : _t(
                        'Pengeluaran lebih besar dari pemasukan.',
                        'Expenses are greater than income.',
                      ),
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF5B6275),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(AnalyticsState data) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: _t('Pemasukan', 'Income'),
            value: data.totalIncome,
            accent: const Color(0xFF00D4AA),
            icon: Icons.south_west_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: _t('Pengeluaran', 'Expense'),
            value: data.totalExpense,
            accent: const Color(0xFFFF5A6E),
            icon: Icons.north_east_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double value,
    required Color accent,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF5B6275),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencySettings.formatCompact(value),
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1E2A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard(List<BarMetric> metrics) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = metrics.fold<double>(
      0,
      (prev, item) => math.max(prev, math.max(item.income, item.expense)),
    );
    final maxY = maxValue == 0 ? 1000000.0 : maxValue * 1.25;

    return Container(
      height: 270,
      padding: const EdgeInsets.fromLTRB(10, 18, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: isDark
                  ? const Color(0xFF20273C)
                  : const Color(0xFFE8EEFB),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final isIncome = rodIndex == 0;
                return BarTooltipItem(
                  '${isIncome ? _t('Pemasukan', 'Income') : _t('Pengeluaran', 'Expense')}\n${CurrencySettings.format(rod.toY)}',
                  TextStyle(
                    color: isIncome
                        ? const Color(0xFF00D4AA)
                        : const Color(0xFFFF5A6E),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY / 4,
                getTitlesWidget: (value, _) => Text(
                  NumberFormat.compact(
                    locale: CurrencySettings.current.locale,
                  ).format(value),
                  style: TextStyle(
                    color: isDark ? Colors.white38 : const Color(0xFF7B88A6),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= metrics.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      metrics[idx].label,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF5B6275),
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0x22FFFFFF), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: metrics.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: e.value.income,
                  width: 7,
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF00D4AA),
                ),
                BarChartRodData(
                  toY: e.value.expense,
                  width: 7,
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFFFF5A6E),
                ),
              ],
            );
          }).toList(),
        ),
        swapAnimationDuration: const Duration(milliseconds: 650),
        swapAnimationCurve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildPieChartCard(List<CategoryMetric> categories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = categories.fold<double>(0, (sum, c) => sum + c.amount);
    final colors = [
      const Color(0xFF4F6EF7),
      const Color(0xFF00D4AA),
      const Color(0xFFFF5A6E),
      const Color(0xFFFFB020),
      const Color(0xFF22C1C3),
      const Color(0xFF8B5CF6),
    ];
    final top = categories.first;
    final topPercent = total == 0 ? 0 : (top.amount / total * 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 64,
                    sectionsSpace: 2,
                    borderData: FlBorderData(show: false),
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          setState(() => _touchedPieIndex = -1);
                          return;
                        }
                        setState(
                          () => _touchedPieIndex =
                              response!.touchedSection!.touchedSectionIndex,
                        );
                      },
                    ),
                    sections: categories.asMap().entries.map((e) {
                      final touched = _touchedPieIndex == e.key;
                      return PieChartSectionData(
                        value: e.value.amount,
                        color: colors[e.key % colors.length],
                        radius: touched ? 42 : 34,
                        title: '',
                        titleStyle: TextStyle(
                          fontSize: touched ? 13 : 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _t('Kategori Teratas', 'Top Category'),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF6D7892),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizeCategory(top.category),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${topPercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: categories.take(6).toList().asMap().entries.map((e) {
              final percent = total == 0 ? 0 : (e.value.amount / total * 100);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2437)
                      : const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors[e.key % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${localizeCategory(e.value.category)} ${percent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF5B6275),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSpendingCard(
    List<CategoryMetric> categories,
    double totalExpense,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (categories.isEmpty || totalExpense <= 0) {
      return _buildEmptyState(
        text: _t(
          'Belum ada pengeluaran untuk ditampilkan.',
          'No spending data to display yet.',
        ),
      );
    }

    final top = categories.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Column(
        children: top.map((item) {
          final pct = (item.amount / totalExpense).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localizeCategory(item.category),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1E2A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      CurrencySettings.format(item.amount),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF5B6275),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: pct,
                    backgroundColor: isDark
                        ? const Color(0xFF1E2437)
                        : const Color(0xFFDDE5F7),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4F6EF7),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberContributionsCard(
    List<UserContributionMetric> contributions,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Column(
        children: contributions.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2437)
                            : const Color(0xFFEAF1FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF5B6275),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.displayName,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 42),
                    const Icon(
                      Icons.south_west_rounded,
                      size: 13,
                      color: Color(0xFF00D4AA),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      CurrencySettings.formatCompact(item.totalIncome),
                      style: const TextStyle(
                        color: Color(0xFF00D4AA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.north_east_rounded,
                      size: 13,
                      color: Color(0xFFFF5A6E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      CurrencySettings.formatCompact(item.totalExpense),
                      style: const TextStyle(
                        color: Color(0xFFFF5A6E),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState({String? text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayText =
        text ?? _t('Belum ada data analitik.', 'No analytics data yet.');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_rounded,
            color: isDark ? Colors.white38 : const Color(0xFF7B88A6),
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            displayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF5B6275),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF151A2A) : const Color(0xFFEAF1FF),
      highlightColor: isDark
          ? const Color(0xFF242B42)
          : const Color(0xFFF6F9FF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            height: 270,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            height: 310,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

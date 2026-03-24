import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/budget_usage_model.dart';
import '../budget_notifier.dart';
import '../widgets/add_budget_sheet.dart';
import '../widgets/budget_card.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/widgets/app_shimmer.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final budgetState = ref.watch(budgetNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0F)
          : const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _t('Pelacak Budget', 'Budget Tracker'),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1E2A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetSheet(context),
        backgroundColor: const Color(0xFF4F6EF7),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: budgetState.when(
          data: (state) => _buildContent(context, ref, state),
          loading: () => const ShimmerCardList(
            itemCount: 5,
            padding: EdgeInsets.fromLTRB(24, 16, 24, 20),
          ),
          error: (err, _) => Center(
            child: Text(
              '${_t('Error', 'Error')}: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, BudgetState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white54 : const Color(0xFF5B6275);
    final usages = state.usages;

    double totalLimit = usages.fold(0, (sum, item) => sum + item.limitAmount);
    double totalSpent = usages.fold(0, (sum, item) => sum + item.spentAmount);
    double totalUsagePct = totalLimit > 0 ? (totalSpent / totalLimit) : 0.0;

    return RefreshIndicator(
      onRefresh: () => ref.read(budgetNotifierProvider.notifier).reload(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMonthPicker(ref, state.selectedMonth, isDark: isDark),
                  const SizedBox(height: 24),
                  if (usages.isNotEmpty)
                    _buildSummaryCard(
                      totalLimit,
                      totalSpent,
                      totalUsagePct,
                      isDark: isDark,
                    ),
                  const SizedBox(height: 32),
                  Text(
                    _t('Budget per Kategori', 'Budget by Category'),
                    style: TextStyle(
                      color: title,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (usages.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _t('Belum ada budget diset', 'No budgets set yet'),
                      style: TextStyle(color: muted, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showAddBudgetSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF1C1C2E)
                            : Colors.white,
                      ),
                      child: Text(
                        _t('Set Budget Pertama', 'Set Your First Budget'),
                        style: const TextStyle(color: Color(0xFF4F6EF7)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => BudgetCard(
                    budget: usages[index],
                    onTap: () =>
                        _showBudgetActions(context, ref, usages[index]),
                    onEdit: () => _showAddBudgetSheet(
                      context,
                      initialCategory: usages[index].category,
                      initialAmount: usages[index].limitAmount,
                    ),
                    onDelete: () async {
                      await ref
                          .read(budgetNotifierProvider.notifier)
                          .deleteBudget(usages[index].category);
                    },
                  ),
                  childCount: usages.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(
    WidgetRef ref,
    DateTime currentMonth, {
    required bool isDark,
  }) {
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white54 : const Color(0xFF6D7892);
    final locale = LanguageSettings.current.locale.toString();
    final monthStr = DateFormat('MMMM yyyy', locale).format(currentMonth);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios, color: muted, size: 18),
          onPressed: () {
            final prev = DateTime(currentMonth.year, currentMonth.month - 1, 1);
            ref.read(budgetNotifierProvider.notifier).changeMonth(prev);
          },
        ),
        Text(
          monthStr,
          style: TextStyle(
            color: title,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: Icon(Icons.arrow_forward_ios, color: muted, size: 18),
          onPressed: () {
            final next = DateTime(currentMonth.year, currentMonth.month + 1, 1);
            ref.read(budgetNotifierProvider.notifier).changeMonth(next);
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    double totalLimit,
    double totalSpent,
    double usagePct, {
    required bool isDark,
  }) {
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6275);
    Color barColor = const Color(0xFF00D4AA);
    if (usagePct >= 0.9) {
      barColor = const Color(0xFFFF4C4C);
    } else if (usagePct >= 0.7) {
      barColor = Colors.amber;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1C1C2E), Color(0xFF2A1F5E)]
              : const [Color(0xFFEAF1FF), Color(0xFFDDE9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Total Budget Bulan Ini', 'Total Budget This Month'),
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencySettings.formatCompact(totalLimit),
            style: TextStyle(
              color: title,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_t('Terpakai', 'Used')}: ${CurrencySettings.formatCompact(totalSpent)}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              Text(
                '${(usagePct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: barColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: usagePct.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: isDark
                  ? Colors.white12
                  : const Color(0xFFDDE5F7),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddBudgetSheet(
    BuildContext context, {
    String? initialCategory,
    double? initialAmount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddBudgetSheet(
        initialCategory: initialCategory,
        initialAmount: initialAmount,
      ),
    );
  }

  void _showBudgetActions(
    BuildContext context,
    WidgetRef ref,
    BudgetUsageModel budget,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141420) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.edit_rounded,
                    color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                  ),
                  title: Text(
                    _t('Edit Budget', 'Edit Budget'),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddBudgetSheet(
                      context,
                      initialCategory: budget.category,
                      initialAmount: budget.limitAmount,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    _t('Hapus Budget', 'Delete Budget'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref
                        .read(budgetNotifierProvider.notifier)
                        .deleteBudget(budget.category);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

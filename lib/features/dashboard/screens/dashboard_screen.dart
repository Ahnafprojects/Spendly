import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../transaction/transaction_notifier.dart';
import '../../transaction/screens/transaction_detail_screen.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../../shared/widgets/app_shimmer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);
    String t(String id, String en) => AppText.t(id: id, en: en);
    final transactionState = ref.watch(transactionNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F7FC);
    final card = isDark ? const Color(0xFF141420) : Colors.white;
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6275);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);

    return Scaffold(
      backgroundColor: bg,
      // FAB Custom dengan Gradient
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF4F6EF7), Color(0xFF00D4AA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F6EF7).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.pushNamed('add-transaction'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF4F6EF7),
          backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
          onRefresh: () =>
              ref.read(transactionNotifierProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAppBar(context),
                      const SizedBox(height: 32),

                      // Hero Element: Balance Card
                      transactionState.when(
                        data: (transactions) =>
                            _buildBalanceCard(transactions, isDark: isDark),
                        loading: () => const SizedBox(
                          height: 170,
                          child: AppShimmer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(22),
                                ),
                              ),
                            ),
                          ),
                        ),
                        error: (err, stack) => Text(
                          '${t('Error', 'Error')}: $err',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildQuickActions(context),
                      const SizedBox(height: 18),
                      _buildGoalsSummaryCard(context, isDark: isDark),
                      const SizedBox(height: 32),

                      // Header Recent Transactions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t('Transaksi Terbaru', 'Recent Transactions'),
                            style: TextStyle(
                              color: title,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/transactions'),
                            child: Text(
                              t('Lihat Semua', 'See All'),
                              style: const TextStyle(color: Color(0xFF4F6EF7)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // List Transaksi
              transactionState.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return _buildEmptyState(isDark: isDark, t: t);
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final tx = transactions[index];
                      return _buildTransactionItem(
                        context,
                        ref,
                        tx,
                        isDark: isDark,
                        card: card,
                        muted: muted,
                        title: title,
                      );
                    }, childCount: transactions.length),
                  );
                },
                loading: () =>
                    const SliverFillRemaining(child: ShimmerDashboard()),
                error: (_, __) =>
                    const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ), // Padding bawah untuk FAB
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET KOMPONEN ---

  Widget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white70 : const Color(0xFF5B6275);
    final userEmail = Supabase.instance.client.auth.currentUser?.email;
    final displayName = (userEmail != null && userEmail.isNotEmpty)
        ? userEmail.split('@').first
        : AppText.t(id: 'Pengguna', en: 'User');
    final dateLabel = DateFormat(
      'EEEE, d MMM',
      LanguageSettings.current.locale.toString(),
    ).format(DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel, style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              '${AppText.t(id: 'Halo', en: 'Hi')}, $displayName',
              style: TextStyle(
                color: title,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2033) : const Color(0xFFE9EEFA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
            ),
          ),
          child: Icon(
            Icons.person_rounded,
            color: isDark ? Colors.white70 : const Color(0xFF24314F),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(
    List<TransactionModel> transactions, {
    required bool isDark,
  }) {
    // Hitung total dari data transaksi real.
    double totalIncome = transactions
        .where((t) => t.type == 'income')
        .fold(0, (sum, t) => sum + t.amount);
    double totalExpense = transactions
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);
    double balance = totalIncome - totalExpense;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF151A2A), Color(0xFF222B45)]
              : const [Color(0xFFEAF1FF), Color(0xFFDCE9FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF0D111D) : const Color(0xFF8AA2D8))
                .withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppText.t(id: 'Total Saldo', en: 'Total Balance'),
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF5B6275),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: balance),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final formattedValue = CurrencySettings.format(value);
              return Text(
                formattedValue,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildIncomeExpense(
                  AppText.t(id: 'Pemasukan', en: 'Income'),
                  totalIncome,
                  true,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildIncomeExpense(
                  AppText.t(id: 'Pengeluaran', en: 'Expense'),
                  totalExpense,
                  false,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpense(
    String title,
    double amount,
    bool isIncome, {
    required bool isDark,
  }) {
    final color = isIncome ? const Color(0xFF00D4AA) : const Color(0xFFFF4C4C);
    final icon = isIncome ? Icons.south_west_rounded : Icons.north_east_rounded;
    final formatted = CurrencySettings.format(amount);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFF1F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF5B6275),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final items = [
      (
        icon: Icons.add_rounded,
        label: AppText.t(id: 'Tambah', en: 'Add'),
        color: const Color(0xFF4F6EF7),
        onTap: () => context.pushNamed('add-transaction'),
      ),
      (
        icon: Icons.savings_rounded,
        label: AppText.t(id: 'Target', en: 'Goals'),
        color: const Color(0xFF00D4AA),
        onTap: () => context.pushNamed('transfer'),
      ),
      (
        icon: Icons.receipt_long_rounded,
        label: AppText.t(id: 'Tagihan', en: 'Bills'),
        color: const Color(0xFFFFB020),
        onTap: () => context.push('/transactions'),
      ),
      (
        icon: Icons.bar_chart_rounded,
        label: AppText.t(id: 'Analitik', en: 'Analytics'),
        color: const Color(0xFF22C1C3),
        onTap: () => context.pushNamed('analytics'),
      ),
      (
        icon: Icons.account_balance_wallet_rounded,
        label: AppText.t(id: 'Budget', en: 'Budget'),
        color: const Color(0xFF8B5CF6),
        onTap: () => context.pushNamed('budget'),
      ),
      (
        icon: Icons.settings_rounded,
        label: AppText.t(id: 'Pengaturan', en: 'Settings'),
        color: const Color(0xFF8B5CF6),
        onTap: () => context.pushNamed('settings'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
        mainAxisExtent: 78,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return _buildActionItem(
          icon: item.icon,
          label: item.label,
          color: item.color,
          isDark: Theme.of(context).brightness == Brightness.dark,
          onTap: item.onTap,
        );
      },
    );
  }

  Widget _buildGoalsSummaryCard(BuildContext context, {required bool isDark}) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);
    return FutureBuilder<_GoalSummary?>(
      future: _loadTopGoal(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 86,
            child: AppShimmer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
          );
        }
        final goal = snapshot.data;
        if (goal == null) {
          return InkWell(
            onTap: () => context.pushNamed('transfer'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151A2A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_rounded, color: Color(0xFF2E90FA)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppText.t(
                        id: 'Belum ada target. Ketuk untuk membuat target pertama.',
                        en: 'No goals yet. Tap to create your first savings goal.',
                      ),
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF2E90FA),
                  ),
                ],
              ),
            ),
          );
        }
        final pct = (goal.current / goal.target).clamp(0.0, 1.0);
        return InkWell(
          onTap: () => context.pushNamed('transfer'),
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                    const Icon(
                      Icons.flag_rounded,
                      color: Color(0xFF2E90FA),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${AppText.t(id: 'Target Utama', en: 'Top Goal')}: ${goal.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFF2E90FA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: pct,
                    backgroundColor: isDark
                        ? const Color(0xFF21314D)
                        : const Color(0xFFE3ECFF),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2E90FA),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${CurrencySettings.format(goal.current)} / ${CurrencySettings.format(goal.target)}',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_GoalSummary?> _loadTopGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('savings_goals_v1');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final goals = decoded
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            return _GoalSummary(
              title: (m['title'] ?? '').toString(),
              target: (m['target'] as num?)?.toDouble() ?? 0,
              current: (m['current'] as num?)?.toDouble() ?? 0,
            );
          })
          .where((g) => g.target > 0)
          .toList();
      if (goals.isEmpty) return null;
      goals.sort(
        (a, b) => (b.current / b.target).compareTo(a.current / a.target),
      );
      return goals.first;
    } catch (_) {
      return null;
    }
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1E2A),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isDark,
    required String Function(String, String) t,
  }) {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long,
                size: 80,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 16),
              Text(
                t('Belum ada transaksi', 'No transactions yet'),
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF5B6275),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    WidgetRef ref,
    TransactionModel tx, {
    required bool isDark,
    required Color card,
    required Color muted,
    required Color title,
  }) {
    final isIncome = tx.type == 'income';
    final amountColor = isIncome
        ? const Color(0xFF00D4AA)
        : const Color(0xFFFF4C4C);
    final sign = isIncome ? '+' : '-';
    final formattedAmount = CurrencySettings.format(tx.amount);
    final formattedDate = DateFormat(
      'dd MMM yyyy',
      LanguageSettings.current.locale.toString(),
    ).format(tx.date);

    final categoryIcon = categoryIconFor(tx.category);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4C4C),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(transactionNotifierProvider.notifier).deleteTransaction(tx.id);
        AppNotice.info(
          context,
          AppText.t(id: 'Transaksi dihapus', en: 'Transaction deleted'),
        );
      },
      child: InkWell(
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: tx),
            ),
          );
          if (changed == true) {
            await ref.read(transactionNotifierProvider.notifier).refresh();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFDCE2F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C2E)
                      : const Color(0xFFE9EEFA),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIcon,
                  color: const Color(0xFF4F6EF7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.note != null && tx.note!.isNotEmpty
                          ? tx.note!
                          : localizeCategory(tx.category),
                      style: TextStyle(
                        color: title,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${localizeCategory(tx.category)} • $formattedDate',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '$sign $formattedAmount',
                style: TextStyle(
                  color: amountColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalSummary {
  final String title;
  final double target;
  final double current;

  const _GoalSummary({
    required this.title,
    required this.target,
    required this.current,
  });
}

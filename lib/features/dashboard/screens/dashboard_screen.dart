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
import '../../account/account_model.dart';
import '../../account/account_notifier.dart';
import '../../account/widgets/transfer_sheet.dart';
import '../../transaction/transaction_notifier.dart';
import '../../transaction/screens/transaction_detail_screen.dart';
import '../../../shared/models/transaction_model.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../../shared/widgets/app_shimmer.dart';

final dashboardBalanceHiddenProvider = StateProvider<bool>((ref) => false);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);
    String t(String id, String en) => AppText.t(id: id, en: en);
    final transactionState = ref.watch(transactionNotifierProvider);
    final accountState = ref.watch(accountNotifierProvider);
    final activeAccountId = ref.watch(activeAccountIdProvider);
    final activeAccount = ref.watch(activeAccountProvider);
    final balances =
        ref.watch(accountBalancesProvider).valueOrNull ??
        const <String, double>{};
    final isBalanceHidden = ref.watch(dashboardBalanceHiddenProvider);
    final currentBalance = activeAccount == null
        ? 0.0
        : (balances[activeAccount.id] ?? activeAccount.initialBalance);
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
                        data: (transactions) => _buildBalanceCard(
                          transactions,
                          isDark: isDark,
                          balanceValue: currentBalance,
                          hideAmount: isBalanceHidden,
                          onToggleHide: () {
                            ref
                                    .read(
                                      dashboardBalanceHiddenProvider.notifier,
                                    )
                                    .state =
                                !isBalanceHidden;
                          },
                        ),
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
                      const SizedBox(height: 12),
                      accountState.when(
                        data: (accounts) => _buildCompactAccountSwitcher(
                          context,
                          ref,
                          accounts: accounts,
                          activeId: activeAccountId,
                          balances: balances,
                          hideAmount: isBalanceHidden,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 32),
                      _buildQuickActions(context),
                      const SizedBox(height: 18),
                      _buildGoalsSummaryCard(
                        context,
                        isDark: isDark,
                        hideAmount: isBalanceHidden,
                      ),
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
                            onPressed: () => context.go('/transactions'),
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

  Widget _buildCompactAccountSwitcher(
    BuildContext context,
    WidgetRef ref, {
    required List<AccountModel> accounts,
    required String? activeId,
    required Map<String, double> balances,
    required bool hideAmount,
  }) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final account = accounts[index];
          final selected = account.id == activeId;
          final balance = balances[account.id] ?? account.initialBalance;
          return InkWell(
            onTap: () => ref
                .read(accountNotifierProvider.notifier)
                .switchAccount(account.id),
            borderRadius: BorderRadius.circular(999),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            overlayColor: const WidgetStatePropertyAll<Color>(
              Colors.transparent,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF4F6EF7).withValues(alpha: 0.14)
                    : (isDark
                          ? const Color(0xFF1A2033)
                          : const Color(0xFFEFF3FF)),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF4F6EF7)
                      : (isDark ? Colors.white12 : const Color(0xFFD8E1F7)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    accountIconData(account.icon),
                    size: 14,
                    color: selected
                        ? const Color(0xFF4F6EF7)
                        : (isDark ? Colors.white70 : const Color(0xFF425173)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hideAmount
                        ? '••••'
                        : CurrencySettings.formatCompact(balance),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white60 : const Color(0xFF5B6275),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
    required double balanceValue,
    required bool hideAmount,
    required VoidCallback onToggleHide,
  }) {
    // Hitung total dari data transaksi real.
    double totalIncome = transactions
        .where(
          (t) =>
              t.type == 'income' ||
              (t.type == 'transfer' && t.transferDirection == 'in'),
        )
        .fold(0, (sum, t) => sum + t.amount);
    double totalExpense = transactions
        .where(
          (t) =>
              t.type == 'expense' ||
              (t.type == 'transfer' && t.transferDirection == 'out'),
        )
        .fold(0, (sum, t) => sum + t.amount);
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
          Row(
            children: [
              Expanded(
                child: Text(
                  AppText.t(id: 'Total Saldo', en: 'Total Balance'),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF5B6275),
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleHide,
                iconSize: 20,
                splashRadius: 18,
                color: isDark ? Colors.white70 : const Color(0xFF5B6275),
                tooltip: hideAmount
                    ? AppText.t(id: 'Tampilkan saldo', en: 'Show balance')
                    : AppText.t(id: 'Sembunyikan saldo', en: 'Hide balance'),
                icon: Icon(
                  hideAmount
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (hideAmount)
            Text(
              '••••••',
              key: const ValueKey<String>('hidden-balance'),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 340),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0, 0.12),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: Text(
                CurrencySettings.format(balanceValue),
                key: ValueKey<String>(balanceValue.toStringAsFixed(2)),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1A1E2A),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildIncomeExpense(
                  AppText.t(id: 'Pemasukan', en: 'Income'),
                  totalIncome,
                  true,
                  hideAmount: hideAmount,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildIncomeExpense(
                  AppText.t(id: 'Pengeluaran', en: 'Expense'),
                  totalExpense,
                  false,
                  hideAmount: hideAmount,
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
    required bool hideAmount,
    required bool isDark,
  }) {
    final color = isIncome ? const Color(0xFF00D4AA) : const Color(0xFFFF4C4C);
    final icon = isIncome ? Icons.south_west_rounded : Icons.north_east_rounded;
    final formatted = hideAmount ? '••••••' : CurrencySettings.format(amount);

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
        icon: Icons.compare_arrows_rounded,
        label: AppText.t(id: 'Transfer', en: 'Transfer'),
        color: const Color(0xFF00D4AA),
        onTap: () async {
          final transferred = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const TransferSheet(),
          );
          if (!context.mounted || transferred != true) return;
          AppNotice.success(
            context,
            AppText.t(id: 'Transfer berhasil', en: 'Transfer successful'),
          );
        },
      ),
      (
        icon: Icons.bar_chart_rounded,
        label: AppText.t(id: 'Analitik', en: 'Analytics'),
        color: const Color(0xFF22C1C3),
        onTap: () => context.pushNamed('analytics'),
      ),
      (
        icon: Icons.pie_chart_rounded,
        label: AppText.t(id: 'Budget', en: 'Budget'),
        color: const Color(0xFF8B5CF6),
        onTap: () => context.pushNamed('budget'),
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

  Widget _buildGoalsSummaryCard(
    BuildContext context, {
    required bool isDark,
    required bool hideAmount,
  }) {
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
                      hideAmount ? '•••' : '${(pct * 100).toStringAsFixed(1)}%',
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
                  hideAmount
                      ? '•••••• / ••••••'
                      : '${CurrencySettings.format(goal.current)} / ${CurrencySettings.format(goal.target)}',
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
    final isIncome =
        tx.type == 'income' ||
        (tx.type == 'transfer' && tx.transferDirection == 'in');
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

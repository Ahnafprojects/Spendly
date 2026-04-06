import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/services/currency_settings.dart';
import '../../../shared/services/language_settings.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../spaces/space_notifier.dart';
import '../savings_deposit_model.dart';
import '../savings_goal_model.dart';
import '../savings_notifier.dart';
import '../widgets/goal_progress_painter.dart';
import '../widgets/topup_sheet.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  final SavingsGoalModel goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  late Future<List<SavingsDepositModel>> _depositsFuture;

  @override
  void initState() {
    super.initState();
    _depositsFuture = ref
        .read(savingsNotifierProvider.notifier)
        .fetchDeposits(widget.goal.id);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    ref.watch(appLanguageProvider);

    final state = ref.watch(savingsNotifierProvider);
    final liveGoal = state.valueOrNull
        ?.where((g) => g.id == widget.goal.id)
        .firstOrNull;
    final goal = liveGoal ?? widget.goal;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F7FC);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);
    final baseColor = goal.colorValue;
    final monthlyNeeded = goal.monthlyNeeded(DateTime.now());

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          goal.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: title, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _deleteGoal,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(savingsNotifierProvider.notifier).refresh();
          _reloadDeposits();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Hero(
              tag: 'goal-${goal.id}',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _lighten(baseColor, 0.22),
                        _darken(baseColor, 0.16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          savingsGoalIconData(goal.icon),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size.square(150),
                              painter: GoalProgressPainter(
                                progress: goal.progress,
                                baseColor: baseColor,
                              ),
                            ),
                            Text(
                              '${(goal.progress * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${CurrencySettings.format(goal.currentAmount)} / ${CurrencySettings.format(goal.targetAmount)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (goal.isCompleted) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFD166,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD166,
                              ).withValues(alpha: 0.7),
                            ),
                          ),
                          child: const Text(
                            'Goal Tercapai',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _infoCard(
              context,
              title: 'Target Amount',
              value: CurrencySettings.format(goal.targetAmount),
            ),
            _infoCard(
              context,
              title: 'Current Amount',
              value: CurrencySettings.format(goal.currentAmount),
            ),
            _infoCard(
              context,
              title: 'Remaining',
              value: CurrencySettings.format(goal.remainingAmount),
            ),
            _infoCard(
              context,
              title: 'Target Date',
              value: DateFormat(
                'dd MMM yyyy',
                LanguageSettings.current.locale.toString(),
              ).format(goal.targetDate),
            ),
            _infoCard(
              context,
              title: 'Monthly Needed',
              value: CurrencySettings.format(monthlyNeeded),
              subtitle:
                  'Berapa yang harus ditabung per bulan untuk mencapai target',
            ),
            const SizedBox(height: 10),
            Text(
              'History Top-Up',
              style: TextStyle(
                color: title,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<SavingsDepositModel>>(
              future: _depositsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Gagal memuat riwayat: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final items = snapshot.data ?? const <SavingsDepositModel>[];
                if (items.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Belum ada transaksi pada goal ini.',
                      style: TextStyle(color: muted),
                    ),
                  );
                }
                final activeSpaceId = ref.read(activeSpaceIdProvider);
                return Column(
                  children: items.map((item) {
                    final positive = item.amount >= 0;
                    final byLabel =
                        activeSpaceId != null &&
                                item.userName?.isNotEmpty == true
                            ? item.userName!
                            : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151A2A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFDDE5F7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color:
                                  (positive
                                          ? const Color(0xFF00D4AA)
                                          : const Color(0xFF22C1C3))
                                      .withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              positive
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              color: positive
                                  ? const Color(0xFF00D4AA)
                                  : const Color(0xFF22C1C3),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.note?.trim().isNotEmpty == true
                                      ? item.note!
                                      : (positive ? 'Top Up' : 'Withdraw'),
                                  style: TextStyle(
                                    color: title,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  byLabel != null
                                      ? '${DateFormat('dd MMM yyyy HH:mm', LanguageSettings.current.locale.toString()).format(item.createdAt)} • By: $byLabel'
                                      : DateFormat(
                                          'dd MMM yyyy HH:mm',
                                          LanguageSettings.current.locale
                                              .toString(),
                                        ).format(item.createdAt),
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${positive ? '+' : '-'} ${CurrencySettings.format(item.absoluteAmount)}',
                            style: TextStyle(
                              color: positive
                                  ? const Color(0xFF00D4AA)
                                  : const Color(0xFF22C1C3),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _onTopUp,
                icon: const Icon(Icons.add_rounded),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F6EF7),
                  minimumSize: const Size.fromHeight(50),
                ),
                label: const Text('Top Up'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _onWithdraw,
                icon: const Icon(Icons.arrow_upward_rounded),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C1C3),
                  minimumSize: const Size.fromHeight(50),
                ),
                label: const Text('Tarik Dana'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required String value,
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: muted, fontSize: 12.5)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: muted, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(color: text, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _onTopUp() async {
    final result = await showModalBottomSheet<TopUpSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF12192B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TopUpSheet(goal: widget.goal),
    );
    if (result == null) return;

    try {
      await ref
          .read(savingsNotifierProvider.notifier)
          .topUp(
            goalId: widget.goal.id,
            amount: result.amount,
            accountId: result.accountId,
            note: result.note,
          );
      if (!mounted) return;
      AppNotice.success(context, 'Top up berhasil');
      _reloadDeposits();
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, 'Top up gagal: $e');
    }
  }

  Future<void> _onWithdraw() async {
    final result = await showModalBottomSheet<TopUpSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF12192B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TopUpSheet(goal: widget.goal, isWithdraw: true),
    );
    if (result == null) return;

    try {
      await ref
          .read(savingsNotifierProvider.notifier)
          .withdraw(
            goalId: widget.goal.id,
            amount: result.amount,
            accountId: result.accountId,
            note: result.note,
          );
      if (!mounted) return;
      AppNotice.success(context, 'Dana berhasil ditarik');
      _reloadDeposits();
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, 'Tarik dana gagal: $e');
    }
  }

  Future<void> _deleteGoal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus goal?'),
        content: Text('Goal "${widget.goal.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(savingsNotifierProvider.notifier)
          .deleteGoal(widget.goal.id);
      if (!mounted) return;
      AppNotice.info(context, 'Goal dihapus');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, 'Gagal hapus goal: $e');
    }
  }

  void _reloadDeposits() {
    setState(() {
      _depositsFuture = ref
          .read(savingsNotifierProvider.notifier)
          .fetchDeposits(widget.goal.id);
    });
  }

  Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}

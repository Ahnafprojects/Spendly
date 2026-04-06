import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/currency_settings.dart';
import '../../../shared/widgets/app_notice.dart';
import '../savings_goal_model.dart';
import '../savings_notifier.dart';
import '../widgets/add_goal_sheet.dart';
import '../widgets/goal_card.dart';
import 'goal_detail_screen.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final state = ref.watch(savingsNotifierProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F7FC);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Savings Goals',
          style: TextStyle(color: title, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_savings_add_goal',
        onPressed: () => _showAddGoalSheet(context, ref),
        backgroundColor: const Color(0xFF4F6EF7),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tambah Goal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(savingsNotifierProvider.notifier).refresh(),
        child: state.when(
          data: (goals) => _GoalsBody(goals: goals),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Gagal memuat goals: $err',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddGoalSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<SavingsGoalModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF12192B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddGoalSheet(),
    );
    if (result == null) return;

    try {
      await ref.read(savingsNotifierProvider.notifier).createGoal(result);
      if (!context.mounted) return;
      AppNotice.success(context, 'Savings goal berhasil dibuat');
    } catch (e) {
      if (!context.mounted) return;
      AppNotice.error(context, 'Gagal membuat goal: $e');
    }
  }
}

class _GoalsBody extends StatelessWidget {
  final List<SavingsGoalModel> goals;

  const _GoalsBody({required this.goals});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);

    final activeGoals = goals.where((g) => !g.isCompleted).toList();
    final totalActiveSavings = activeGoals.fold<double>(
      0,
      (sum, g) => sum + g.currentAmount,
    );

    if (goals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.savings_rounded,
            size: 76,
            color: isDark ? Colors.white24 : const Color(0xFFA4B3D2),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada savings goal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: title,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buat goal pertamamu dan top up secara berkala.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ],
      );
    }

    final useList = goals.length > 6;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
              Text(
                'Total Tabungan Aktif',
                style: TextStyle(color: muted, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencySettings.format(totalActiveSavings),
                style: TextStyle(
                  color: title,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (useList)
          ...goals.map((goal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 270,
                child: GoalCard(
                  goal: goal,
                  onTap: () => _openDetail(context, goal),
                ),
              ),
            );
          })
        else
          GridView.builder(
            shrinkWrap: true,
            itemCount: goals.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 270,
            ),
            itemBuilder: (_, index) {
              final goal = goals[index];
              return GoalCard(
                goal: goal,
                onTap: () => _openDetail(context, goal),
              );
            },
          ),
      ],
    );
  }

  void _openDetail(BuildContext context, SavingsGoalModel goal) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GoalDetailScreen(goal: goal)));
  }
}

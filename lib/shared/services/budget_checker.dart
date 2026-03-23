import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/budget/budget_repository.dart';
import 'offline_store.dart';
import 'notification_service.dart';

class BudgetChecker {
  static Future<void> checkAndNotify(DateTime transactionDate) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final repository = BudgetRepository(offlineStore: OfflineStore());
      final usages = await repository.fetchBudgetUsage(transactionDate);

      for (final usage in usages) {
        if (usage.isOver) {
          final excess = usage.spentAmount - usage.limitAmount;
          await NotificationService.showBudgetExceeded(usage.category, excess);
        } else if (usage.usagePct >= 80.0) {
          await NotificationService.showBudgetWarning(
            usage.category,
            usage.usagePct,
            usage.limitAmount,
          );
        }
      }
    } catch (_) {
      // Silent fail to keep transaction flow stable.
    }
  }
}

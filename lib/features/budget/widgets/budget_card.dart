import 'package:flutter/material.dart';
import '../../../shared/constants/transaction_categories.dart';
import '../../../shared/services/currency_settings.dart';
import '../models/budget_usage_model.dart';

class BudgetCard extends StatelessWidget {
  final BudgetUsageModel budget;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BudgetCard({
    super.key,
    required this.budget,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF141420) : Colors.white;
    final muted = isDark ? Colors.white54 : const Color(0xFF6D7892);
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final currencyFormat = CurrencySettings.compactFormatter();

    Color progressColor = const Color(0xFF00D4AA);
    if (budget.usagePct >= 90) {
      progressColor = const Color(0xFFFF4C4C);
    } else if (budget.usagePct >= 70) {
      progressColor = Colors.amber;
    }

    final double fraction = (budget.usagePct / 100).clamp(0.0, 1.0);

    final icon = categoryIconFor(budget.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: budget.isOver
                ? const Color(0xFFFF4C4C).withValues(alpha: 0.5)
                : (isDark ? Colors.transparent : const Color(0xFFDDE5F7)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C2E)
                            : const Color(0xFFE9EEFA),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF4F6EF7),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      budget.category,
                      style: TextStyle(
                        color: title,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(budget.spentAmount),
                          style: TextStyle(
                            color: progressColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'dari ${currencyFormat.format(budget.limitAmount)}',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          if (onEdit != null)
                            GestureDetector(
                              onTap: onEdit,
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white70,
                              ),
                            ),
                          if (onDelete != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: onDelete,
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: isDark
                    ? const Color(0xFF1C1C2E)
                    : const Color(0xFFE9EEFA),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            if (budget.isOver)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFFF4C4C),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Over Budget! Kamu melebihi ${currencyFormat.format(budget.spentAmount - budget.limitAmount)}',
                      style: const TextStyle(
                        color: Color(0xFFFF4C4C),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

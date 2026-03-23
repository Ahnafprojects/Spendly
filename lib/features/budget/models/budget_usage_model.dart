class BudgetUsageModel {
  final String category;
  final double limitAmount;
  final double spentAmount;
  final double remaining;
  final double usagePct;
  final bool isOver;

  BudgetUsageModel({
    required this.category,
    required this.limitAmount,
    required this.spentAmount,
    required this.remaining,
    required this.usagePct,
    required this.isOver,
  });

  factory BudgetUsageModel.fromJson(Map<String, dynamic> json) {
    return BudgetUsageModel(
      category: json['category'],
      limitAmount: (json['limit_amount'] as num).toDouble(),
      spentAmount: (json['spent_amount'] as num).toDouble(),
      remaining: (json['remaining'] as num).toDouble(),
      usagePct: (json['usage_pct'] as num).toDouble(),
      isOver: json['is_over'] ?? false,
    );
  }
}

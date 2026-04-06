class SavingsDepositModel {
  final String id;
  final String goalId;
  final String userId;
  final double amount;
  final String? note;
  final String? accountId;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  const SavingsDepositModel({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.amount,
    this.note,
    this.accountId,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory SavingsDepositModel.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return SavingsDepositModel(
      id: (json['id'] ?? '').toString(),
      goalId: (json['goal_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      note: json['note']?.toString(),
      accountId: json['account_id']?.toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      userName: profiles?['full_name']?.toString(),
      userEmail: profiles?['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal_id': goalId,
      'user_id': userId,
      'amount': amount,
      'note': note,
      'account_id': accountId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isWithdraw => amount < 0;

  double get absoluteAmount => amount.abs();
}

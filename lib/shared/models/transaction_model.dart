class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'income', 'expense', atau 'transfer'
  final String category;
  final String? note;
  final String? accountId;
  final String? transferDirection; // in / out (khusus transfer)
  final String? transferGroupId;
  final DateTime date;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.category,
    this.note,
    this.accountId,
    this.transferDirection,
    this.transferGroupId,
    required this.date,
    required this.createdAt,
  });

  // Mengubah data dari Supabase menjadi Object Dart
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      userId: json['user_id'],
      amount: (json['amount'] as num).toDouble(),
      type: json['type'],
      category: json['category'],
      note: json['note'],
      accountId: json['account_id']?.toString(),
      transferDirection: json['transfer_direction']?.toString(),
      transferGroupId: json['transfer_group_id']?.toString(),
      date: DateTime.parse(json['date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Mengubah Object Dart menjadi format JSON untuk disimpan ke Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'category': category,
      'note': note,
      'account_id': accountId,
      'transfer_direction': transferDirection,
      'transfer_group_id': transferGroupId,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

import 'package:flutter/material.dart';

class SavingsGoalModel {
  final String id;
  final String userId;
  final String name;
  final String icon;
  final String color;
  final String? spaceId;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavingsGoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.icon,
    required this.color,
    this.spaceId,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingsGoalModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: normalizeSavingsGoalIcon((json['icon'] ?? 'flag').toString()),
      color: (json['color'] ?? '#4F6EF7').toString(),
      spaceId: json['space_id']?.toString(),
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0,
      targetDate:
          DateTime.tryParse((json['target_date'] ?? '').toString()) ??
          DateTime.now(),
      isCompleted: json['is_completed'] == true,
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'space_id': spaceId,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': _dateOnly(targetDate),
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SavingsGoalModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    String? color,
    String? spaceId,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      spaceId: spaceId ?? this.spaceId,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get progress {
    if (targetAmount <= 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  double get remainingAmount {
    final remaining = targetAmount - currentAmount;
    return remaining <= 0 ? 0 : remaining;
  }

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return end.difference(today).inDays;
  }

  double monthlyNeeded(DateTime now) {
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(targetDate.year, targetDate.month, 1);
    var months = (end.year - start.year) * 12 + (end.month - start.month) + 1;
    if (months < 1) months = 1;
    return remainingAmount / months;
  }

  Color get colorValue {
    final cleaned = color.replaceAll('#', '');
    final hex = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF4F6EF7);
  }

  static String _dateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class SavingsGoalIconOption {
  final String key;
  final IconData icon;
  final String label;

  const SavingsGoalIconOption({
    required this.key,
    required this.icon,
    required this.label,
  });
}

const savingsGoalIconOptions = <SavingsGoalIconOption>[
  SavingsGoalIconOption(key: 'home', icon: Icons.home_rounded, label: 'Rumah'),
  SavingsGoalIconOption(
    key: 'car',
    icon: Icons.directions_car_rounded,
    label: 'Mobil',
  ),
  SavingsGoalIconOption(
    key: 'flight',
    icon: Icons.flight_takeoff_rounded,
    label: 'Travel',
  ),
  SavingsGoalIconOption(
    key: 'laptop',
    icon: Icons.laptop_mac_rounded,
    label: 'Laptop',
  ),
  SavingsGoalIconOption(
    key: 'phone',
    icon: Icons.smartphone_rounded,
    label: 'Gadget',
  ),
  SavingsGoalIconOption(
    key: 'ring',
    icon: Icons.diamond_rounded,
    label: 'Pernikahan',
  ),
  SavingsGoalIconOption(
    key: 'education',
    icon: Icons.school_rounded,
    label: 'Pendidikan',
  ),
  SavingsGoalIconOption(
    key: 'vacation',
    icon: Icons.beach_access_rounded,
    label: 'Liburan',
  ),
  SavingsGoalIconOption(
    key: 'camera',
    icon: Icons.camera_alt_rounded,
    label: 'Kamera',
  ),
  SavingsGoalIconOption(
    key: 'game',
    icon: Icons.sports_esports_rounded,
    label: 'Gaming',
  ),
  SavingsGoalIconOption(
    key: 'bag',
    icon: Icons.luggage_rounded,
    label: 'Perjalanan',
  ),
  SavingsGoalIconOption(
    key: 'family',
    icon: Icons.family_restroom_rounded,
    label: 'Keluarga',
  ),
  SavingsGoalIconOption(key: 'work', icon: Icons.work_rounded, label: 'Karier'),
  SavingsGoalIconOption(
    key: 'furniture',
    icon: Icons.weekend_rounded,
    label: 'Furnitur',
  ),
  SavingsGoalIconOption(
    key: 'health',
    icon: Icons.local_hospital_rounded,
    label: 'Kesehatan',
  ),
  SavingsGoalIconOption(
    key: 'gift',
    icon: Icons.card_giftcard_rounded,
    label: 'Hadiah',
  ),
  SavingsGoalIconOption(
    key: 'bank',
    icon: Icons.account_balance_rounded,
    label: 'Keuangan',
  ),
  SavingsGoalIconOption(
    key: 'fitness',
    icon: Icons.fitness_center_rounded,
    label: 'Fitness',
  ),
  SavingsGoalIconOption(
    key: 'bicycle',
    icon: Icons.pedal_bike_rounded,
    label: 'Sepeda',
  ),
  SavingsGoalIconOption(key: 'pets', icon: Icons.pets_rounded, label: 'Hewan'),
  SavingsGoalIconOption(
    key: 'book',
    icon: Icons.menu_book_rounded,
    label: 'Buku',
  ),
  SavingsGoalIconOption(
    key: 'target',
    icon: Icons.track_changes_rounded,
    label: 'Target',
  ),
  SavingsGoalIconOption(
    key: 'wallet',
    icon: Icons.account_balance_wallet_rounded,
    label: 'Dana',
  ),
  SavingsGoalIconOption(key: 'flag', icon: Icons.flag_rounded, label: 'Goal'),
];

IconData savingsGoalIconData(String key) {
  for (final option in savingsGoalIconOptions) {
    if (option.key == key) return option.icon;
  }
  return Icons.flag_rounded;
}

String normalizeSavingsGoalIcon(String key) {
  for (final option in savingsGoalIconOptions) {
    if (option.key == key) return key;
  }
  return 'flag';
}

import 'package:flutter/material.dart';

class AccountModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String icon;
  final String color;
  final String? spaceId;
  final double initialBalance;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.spaceId,
    required this.initialBalance,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'other').toString(),
      icon: (json['icon'] ?? '💳').toString(),
      color: (json['color'] ?? '#4F6EF7').toString(),
      spaceId: json['space_id']?.toString(),
      initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0,
      isDefault: json['is_default'] == true,
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
      'type': type,
      'icon': icon,
      'color': color,
      'space_id': spaceId,
      'initial_balance': initialBalance,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  AccountModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? icon,
    String? color,
    String? spaceId,
    double? initialBalance,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      spaceId: spaceId ?? this.spaceId,
      initialBalance: initialBalance ?? this.initialBalance,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Color get colorValue {
    final clean = color.replaceAll('#', '');
    final hex = clean.length == 6 ? 'FF$clean' : clean;
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF4F6EF7);
  }
}

class AccountIconOption {
  final String key;
  final IconData icon;
  final String idLabel;
  final String enLabel;

  const AccountIconOption({
    required this.key,
    required this.icon,
    required this.idLabel,
    required this.enLabel,
  });
}

const accountIconOptions = <AccountIconOption>[
  AccountIconOption(
    key: 'wallet',
    icon: Icons.account_balance_wallet_rounded,
    idLabel: 'Dompet',
    enLabel: 'Wallet',
  ),
  AccountIconOption(
    key: 'bank',
    icon: Icons.account_balance_rounded,
    idLabel: 'Bank',
    enLabel: 'Bank',
  ),
  AccountIconOption(
    key: 'card',
    icon: Icons.credit_card_rounded,
    idLabel: 'Kartu',
    enLabel: 'Card',
  ),
  AccountIconOption(
    key: 'cash',
    icon: Icons.payments_rounded,
    idLabel: 'Tunai',
    enLabel: 'Cash',
  ),
  AccountIconOption(
    key: 'phone',
    icon: Icons.phone_android_rounded,
    idLabel: 'E-Wallet',
    enLabel: 'E-Wallet',
  ),
  AccountIconOption(
    key: 'vault',
    icon: Icons.savings_rounded,
    idLabel: 'Tabungan',
    enLabel: 'Savings',
  ),
  AccountIconOption(
    key: 'invest',
    icon: Icons.trending_up_rounded,
    idLabel: 'Investasi',
    enLabel: 'Investment',
  ),
  AccountIconOption(
    key: 'store',
    icon: Icons.storefront_rounded,
    idLabel: 'Bisnis',
    enLabel: 'Business',
  ),
  AccountIconOption(
    key: 'home',
    icon: Icons.home_rounded,
    idLabel: 'Rumah',
    enLabel: 'Home',
  ),
  AccountIconOption(
    key: 'car',
    icon: Icons.directions_car_rounded,
    idLabel: 'Transport',
    enLabel: 'Transport',
  ),
  AccountIconOption(
    key: 'travel',
    icon: Icons.flight_rounded,
    idLabel: 'Travel',
    enLabel: 'Travel',
  ),
  AccountIconOption(
    key: 'food',
    icon: Icons.restaurant_rounded,
    idLabel: 'Makan',
    enLabel: 'Food',
  ),
  AccountIconOption(
    key: 'shop',
    icon: Icons.shopping_bag_rounded,
    idLabel: 'Belanja',
    enLabel: 'Shopping',
  ),
  AccountIconOption(
    key: 'shield',
    icon: Icons.shield_rounded,
    idLabel: 'Proteksi',
    enLabel: 'Protection',
  ),
  AccountIconOption(
    key: 'gift',
    icon: Icons.card_giftcard_rounded,
    idLabel: 'Gift',
    enLabel: 'Gift',
  ),
  AccountIconOption(
    key: 'target',
    icon: Icons.flag_rounded,
    idLabel: 'Target',
    enLabel: 'Target',
  ),
];

IconData accountIconData(String key) {
  for (final option in accountIconOptions) {
    if (option.key == key) return option.icon;
  }
  return Icons.account_balance_wallet_rounded;
}

bool isKnownAccountIconKey(String key) {
  for (final option in accountIconOptions) {
    if (option.key == key) return true;
  }
  return false;
}

String accountTypeLabel(String type, {required bool isEnglish}) {
  switch (type) {
    case 'cash':
      return isEnglish ? 'Cash' : 'Tunai';
    case 'bank':
      return 'Bank';
    case 'ewallet':
      return 'E-Wallet';
    case 'investment':
      return isEnglish ? 'Investment' : 'Investasi';
    default:
      return isEnglish ? 'Other' : 'Lainnya';
  }
}

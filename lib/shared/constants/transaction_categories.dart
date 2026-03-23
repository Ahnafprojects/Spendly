import 'package:flutter/material.dart';

class TransactionCategories {
  static const List<String> expense = [
    'Makanan Harian',
    'Cafe & Nongkrong',
    'Transport Umum',
    'Bensin',
    'Tol & Parkir',
    'Token Listrik',
    'Air PDAM',
    'Internet & WiFi',
    'Pulsa & Data',
    'Sewa/Kos',
    'Belanja Bulanan',
    'Laundry',
    'Perawatan Rumah',
    'Kesehatan & Obat',
    'Gym & Olahraga',
    'Asuransi',
    'Pendidikan',
    'Donasi/Zakat',
    'Hiburan',
    'Langganan Aplikasi',
    'Fashion',
    'Perawatan Diri',
    'Cicilan/Hutang',
    'Pajak & Administrasi',
    'Lainnya',
  ];

  static const List<String> income = [
    'Gaji',
    'Bonus',
    'THR',
    'Uang Saku',
    'Freelance',
    'Proyek Sampingan',
    'Komisi',
    'Penjualan',
    'Pendapatan Usaha',
    'Dividen/Investasi',
    'Bunga Tabungan',
    'Hadiah',
    'Refund',
    'Lainnya',
  ];
}

String normalizeCategoryKey(String input) {
  final lower = input.toLowerCase().trim();
  final lettersOnly = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (lettersOnly.isEmpty) return 'lainnya';

  if (lettersOnly.contains('internaet') ||
      lettersOnly.contains('internet') && lettersOnly.contains('wifi')) {
    return 'internetwifi';
  }
  if (lettersOnly.contains('token') && lettersOnly.contains('listrik')) return 'tokenlistrik';
  if (lettersOnly.contains('air') && lettersOnly.contains('pdam')) return 'airpdam';
  if (lettersOnly.contains('bensin')) return 'bensin';
  if (lettersOnly.contains('tol') || lettersOnly.contains('parkir')) return 'tolparkir';
  if (lettersOnly.contains('makan') || lettersOnly.contains('cafe')) return 'makanancafe';
  if (lettersOnly.contains('pulsa') || lettersOnly.contains('data')) return 'pulsadata';
  if (lettersOnly.contains('belanja')) return 'belanja';
  if (lettersOnly.contains('hiburan')) return 'hiburan';
  if (lettersOnly.contains('kesehatan') || lettersOnly.contains('obat')) return 'kesehatan';
  if (lettersOnly.contains('pendidikan')) return 'pendidikan';
  if (lettersOnly.contains('tagihan')) return 'tagihan';
  if (lettersOnly.contains('sewa') || lettersOnly.contains('kos')) return 'sewakos';
  if (lettersOnly.contains('laundry')) return 'laundry';
  if (lettersOnly.contains('cicilan') || lettersOnly.contains('hutang')) return 'cicilan';
  if (lettersOnly.contains('gaji')) return 'gaji';
  if (lettersOnly.contains('thr')) return 'thr';
  if (lettersOnly.contains('bonus')) return 'bonus';
  if (lettersOnly.contains('freelance')) return 'freelance';
  if (lettersOnly.contains('proyek')) return 'proyek';
  if (lettersOnly.contains('komisi')) return 'komisi';
  if (lettersOnly.contains('usaha') || lettersOnly.contains('penjualan')) return 'usaha';
  if (lettersOnly.contains('dividen') || lettersOnly.contains('investasi')) return 'investasi';
  if (lettersOnly.contains('refund')) return 'refund';
  if (lettersOnly.contains('hadiah')) return 'hadiah';

  return lettersOnly;
}

IconData categoryIconFor(String category) {
  final value = category.toLowerCase();

  if (value.contains('makan') || value.contains('cafe')) return Icons.restaurant;
  if (value.contains('transport')) return Icons.directions_bus_rounded;
  if (value.contains('bensin')) return Icons.local_gas_station_rounded;
  if (value.contains('tol') || value.contains('parkir')) return Icons.local_parking_rounded;
  if (value.contains('token') || value.contains('listrik')) return Icons.electric_bolt_rounded;
  if (value.contains('air pdam') || value == 'air') return Icons.water_drop_rounded;
  if (value.contains('internet') || value.contains('wifi')) return Icons.wifi_rounded;
  if (value.contains('pulsa') || value.contains('data')) return Icons.phone_android_rounded;
  if (value.contains('sewa') || value.contains('kos')) return Icons.home_rounded;
  if (value.contains('belanja')) return Icons.shopping_cart_rounded;
  if (value.contains('laundry')) return Icons.local_laundry_service_rounded;
  if (value.contains('rumah')) return Icons.handyman_rounded;
  if (value.contains('kesehatan') || value.contains('obat')) return Icons.medical_services_rounded;
  if (value.contains('gym') || value.contains('olahraga')) return Icons.fitness_center_rounded;
  if (value.contains('asuransi')) return Icons.health_and_safety_rounded;
  if (value.contains('pendidikan')) return Icons.school_rounded;
  if (value.contains('donasi') || value.contains('zakat')) return Icons.volunteer_activism_rounded;
  if (value.contains('hiburan')) return Icons.movie_rounded;
  if (value.contains('langganan')) return Icons.subscriptions_rounded;
  if (value.contains('fashion')) return Icons.checkroom_rounded;
  if (value.contains('perawatan diri')) return Icons.spa_rounded;
  if (value.contains('cicilan') || value.contains('hutang')) return Icons.account_balance_wallet_rounded;
  if (value.contains('pajak') || value.contains('administrasi')) return Icons.receipt_long_rounded;

  if (value.contains('gaji')) return Icons.payments_rounded;
  if (value.contains('bonus') || value.contains('thr') || value.contains('komisi')) {
    return Icons.workspace_premium_rounded;
  }
  if (value.contains('freelance') || value.contains('proyek')) return Icons.laptop_chromebook_rounded;
  if (value.contains('penjualan') || value.contains('usaha')) return Icons.storefront_rounded;
  if (value.contains('investasi') || value.contains('dividen') || value.contains('bunga')) {
    return Icons.trending_up_rounded;
  }
  if (value.contains('refund')) return Icons.assignment_return_rounded;
  if (value.contains('hadiah')) return Icons.card_giftcard_rounded;

  return Icons.category_rounded;
}

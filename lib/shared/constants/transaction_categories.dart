import 'package:flutter/material.dart';
import '../services/language_settings.dart';

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

const Map<String, Map<String, String>> _localizedCategoryLabels = {
  'id': {
    'makananharian': 'Makanan Harian',
    'caffenongkrong': 'Cafe & Nongkrong',
    'makanancafe': 'Makanan & Cafe',
    'transportumum': 'Transport Umum',
    'bensin': 'Bensin',
    'tolparkir': 'Tol & Parkir',
    'tokenlistrik': 'Token Listrik',
    'airpdam': 'Air PDAM',
    'internetwifi': 'Internet & WiFi',
    'pulsadata': 'Pulsa & Data',
    'sewakos': 'Sewa/Kos',
    'belanja': 'Belanja',
    'laundry': 'Laundry',
    'perawatanrumah': 'Perawatan Rumah',
    'kesehatan': 'Kesehatan',
    'olahraga': 'Gym & Olahraga',
    'asuransi': 'Asuransi',
    'pendidikan': 'Pendidikan',
    'donasi': 'Donasi/Zakat',
    'hiburan': 'Hiburan',
    'langganan': 'Langganan Aplikasi',
    'fashion': 'Fashion',
    'perawatandiri': 'Perawatan Diri',
    'cicilan': 'Cicilan/Hutang',
    'tagihan': 'Pajak & Administrasi',
    'gaji': 'Gaji',
    'bonus': 'Bonus',
    'thr': 'THR',
    'uangsaku': 'Uang Saku',
    'freelance': 'Freelance',
    'proyek': 'Proyek Sampingan',
    'komisi': 'Komisi',
    'penjualan': 'Penjualan',
    'usaha': 'Pendapatan Usaha',
    'investasi': 'Dividen/Investasi',
    'bungatabungan': 'Bunga Tabungan',
    'refund': 'Refund',
    'hadiah': 'Hadiah',
    'lainnya': 'Lainnya',
  },
  'en': {
    'makananharian': 'Daily Meals',
    'caffenongkrong': 'Cafe & Hangout',
    'makanancafe': 'Food & Cafe',
    'transportumum': 'Public Transport',
    'bensin': 'Fuel',
    'tolparkir': 'Toll & Parking',
    'tokenlistrik': 'Electricity Token',
    'airpdam': 'Water Bill',
    'internetwifi': 'Internet & Wi-Fi',
    'pulsadata': 'Phone/Data',
    'sewakos': 'Rent',
    'belanja': 'Shopping',
    'laundry': 'Laundry',
    'perawatanrumah': 'Home Maintenance',
    'kesehatan': 'Health',
    'olahraga': 'Gym & Sports',
    'asuransi': 'Insurance',
    'pendidikan': 'Education',
    'donasi': 'Donation/Zakat',
    'hiburan': 'Entertainment',
    'langganan': 'App Subscription',
    'fashion': 'Fashion',
    'perawatandiri': 'Personal Care',
    'cicilan': 'Installments/Debt',
    'tagihan': 'Tax & Administration',
    'gaji': 'Salary',
    'bonus': 'Bonus',
    'thr': 'Holiday Bonus',
    'uangsaku': 'Allowance',
    'freelance': 'Freelance',
    'proyek': 'Side Project',
    'komisi': 'Commission',
    'penjualan': 'Sales',
    'usaha': 'Business Income',
    'investasi': 'Dividend/Investment',
    'bungatabungan': 'Savings Interest',
    'refund': 'Refund',
    'hadiah': 'Gift',
    'lainnya': 'Others',
  },
};

String localizeCategory(String category) {
  final key = normalizeCategoryKey(category);
  final languageCode = LanguageSettings.current.code;
  final langMap = _localizedCategoryLabels[languageCode];
  final fallback = _localizedCategoryLabels['en'];
  return langMap?[key] ?? fallback?[key] ?? category;
}

String normalizeCategoryKey(String input) {
  final lower = input.toLowerCase().trim();
  final lettersOnly = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (lettersOnly.isEmpty) return 'lainnya';

  if (lettersOnly.contains('internaet') ||
      lettersOnly.contains('internet') && lettersOnly.contains('wifi')) {
    return 'internetwifi';
  }
  if (lettersOnly.contains('token') && lettersOnly.contains('listrik'))
    return 'tokenlistrik';
  if (lettersOnly.contains('air') && lettersOnly.contains('pdam'))
    return 'airpdam';
  if (lettersOnly.contains('bensin')) return 'bensin';
  if (lettersOnly.contains('tol') || lettersOnly.contains('parkir'))
    return 'tolparkir';
  if (lettersOnly.contains('transport')) return 'transportumum';
  if (lettersOnly.contains('cafe') || lettersOnly.contains('nongkrong')) {
    return 'caffenongkrong';
  }
  if (lettersOnly.contains('makan')) return 'makananharian';
  if (lettersOnly.contains('pulsa') || lettersOnly.contains('data'))
    return 'pulsadata';
  if (lettersOnly.contains('belanja')) return 'belanja';
  if (lettersOnly.contains('hiburan')) return 'hiburan';
  if (lettersOnly.contains('rumah')) return 'perawatanrumah';
  if (lettersOnly.contains('gym') || lettersOnly.contains('olahraga'))
    return 'olahraga';
  if (lettersOnly.contains('asuransi')) return 'asuransi';
  if (lettersOnly.contains('kesehatan') || lettersOnly.contains('obat'))
    return 'kesehatan';
  if (lettersOnly.contains('pendidikan')) return 'pendidikan';
  if (lettersOnly.contains('donasi') || lettersOnly.contains('zakat'))
    return 'donasi';
  if (lettersOnly.contains('langganan')) return 'langganan';
  if (lettersOnly.contains('fashion')) return 'fashion';
  if (lettersOnly.contains('perawatandiri')) return 'perawatandiri';
  if (lettersOnly.contains('tagihan')) return 'tagihan';
  if (lettersOnly.contains('pajak') || lettersOnly.contains('administrasi'))
    return 'tagihan';
  if (lettersOnly.contains('sewa') || lettersOnly.contains('kos'))
    return 'sewakos';
  if (lettersOnly.contains('laundry')) return 'laundry';
  if (lettersOnly.contains('cicilan') || lettersOnly.contains('hutang'))
    return 'cicilan';
  if (lettersOnly.contains('gaji')) return 'gaji';
  if (lettersOnly.contains('thr')) return 'thr';
  if (lettersOnly.contains('bonus')) return 'bonus';
  if (lettersOnly.contains('uangsaku')) return 'uangsaku';
  if (lettersOnly.contains('freelance')) return 'freelance';
  if (lettersOnly.contains('proyek')) return 'proyek';
  if (lettersOnly.contains('komisi')) return 'komisi';
  if (lettersOnly.contains('penjualan')) return 'penjualan';
  if (lettersOnly.contains('usaha')) return 'usaha';
  if (lettersOnly.contains('dividen') || lettersOnly.contains('investasi'))
    return 'investasi';
  if (lettersOnly.contains('bunga') || lettersOnly.contains('tabungan'))
    return 'bungatabungan';
  if (lettersOnly.contains('refund')) return 'refund';
  if (lettersOnly.contains('hadiah')) return 'hadiah';

  return lettersOnly;
}

IconData categoryIconFor(String category) {
  final key = normalizeCategoryKey(category);

  if (key == 'makananharian') return Icons.restaurant;
  if (key == 'caffenongkrong') return Icons.local_cafe_rounded;
  if (key == 'makanancafe') return Icons.restaurant;
  if (key == 'transportumum') return Icons.directions_bus_rounded;
  if (key == 'bensin') return Icons.local_gas_station_rounded;
  if (key == 'tolparkir') return Icons.local_parking_rounded;
  if (key == 'tokenlistrik') return Icons.electric_bolt_rounded;
  if (key == 'airpdam') return Icons.water_drop_rounded;
  if (key == 'internetwifi') return Icons.wifi_rounded;
  if (key == 'pulsadata') return Icons.phone_android_rounded;
  if (key == 'sewakos') return Icons.home_rounded;
  if (key == 'belanja') return Icons.shopping_cart_rounded;
  if (key == 'laundry') return Icons.local_laundry_service_rounded;
  if (key == 'perawatanrumah') return Icons.handyman_rounded;
  if (key == 'kesehatan') return Icons.medical_services_rounded;
  if (key == 'olahraga') return Icons.fitness_center_rounded;
  if (key == 'asuransi') return Icons.health_and_safety_rounded;
  if (key == 'pendidikan') return Icons.school_rounded;
  if (key == 'donasi') return Icons.volunteer_activism_rounded;
  if (key == 'hiburan') return Icons.movie_rounded;
  if (key == 'langganan') return Icons.subscriptions_rounded;
  if (key == 'fashion') return Icons.checkroom_rounded;
  if (key == 'perawatandiri') return Icons.spa_rounded;
  if (key == 'cicilan') return Icons.account_balance_wallet_rounded;
  if (key == 'tagihan') return Icons.receipt_long_rounded;

  if (key == 'gaji') return Icons.payments_rounded;
  if (key == 'bonus' || key == 'thr' || key == 'komisi') {
    return Icons.workspace_premium_rounded;
  }
  if (key == 'freelance' || key == 'proyek') {
    return Icons.laptop_chromebook_rounded;
  }
  if (key == 'uangsaku') return Icons.account_balance_wallet_rounded;
  if (key == 'penjualan') return Icons.point_of_sale_rounded;
  if (key == 'usaha') return Icons.storefront_rounded;
  if (key == 'investasi') return Icons.trending_up_rounded;
  if (key == 'bungatabungan') return Icons.savings_rounded;
  if (key == 'refund') return Icons.assignment_return_rounded;
  if (key == 'hadiah') return Icons.card_giftcard_rounded;

  return Icons.category_rounded;
}

import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyOption {
  final String code;
  final String label;
  final String locale;
  final String symbol;
  final int decimalDigits;
  final double rateToIdr;

  const CurrencyOption({
    required this.code,
    required this.label,
    required this.locale,
    required this.symbol,
    required this.decimalDigits,
    required this.rateToIdr,
  });
}

class CurrencySettings {
  static const _kCurrencyCode = 'settings_currency_code';

  static const options = <CurrencyOption>[
    CurrencyOption(
      code: 'IDR',
      label: 'Indonesian Rupiah',
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
      rateToIdr: 1,
    ),
    CurrencyOption(
      code: 'USD',
      label: 'US Dollar',
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
      rateToIdr: 15500,
    ),
    CurrencyOption(
      code: 'AUD',
      label: 'Australian Dollar',
      locale: 'en_AU',
      symbol: 'A\$',
      decimalDigits: 2,
      rateToIdr: 10200,
    ),
    CurrencyOption(
      code: 'CAD',
      label: 'Canadian Dollar',
      locale: 'en_CA',
      symbol: 'C\$',
      decimalDigits: 2,
      rateToIdr: 11400,
    ),
    CurrencyOption(
      code: 'GBP',
      label: 'British Pound',
      locale: 'en_GB',
      symbol: '£',
      decimalDigits: 2,
      rateToIdr: 19800,
    ),
    CurrencyOption(
      code: 'EUR',
      label: 'Euro',
      locale: 'de_DE',
      symbol: '€',
      decimalDigits: 2,
      rateToIdr: 16900,
    ),
    CurrencyOption(
      code: 'SGD',
      label: 'Singapore Dollar',
      locale: 'en_SG',
      symbol: 'S\$',
      decimalDigits: 2,
      rateToIdr: 11500,
    ),
    CurrencyOption(
      code: 'MYR',
      label: 'Malaysian Ringgit',
      locale: 'ms_MY',
      symbol: 'RM',
      decimalDigits: 2,
      rateToIdr: 3300,
    ),
    CurrencyOption(
      code: 'THB',
      label: 'Thai Baht',
      locale: 'th_TH',
      symbol: '฿',
      decimalDigits: 2,
      rateToIdr: 430,
    ),
    CurrencyOption(
      code: 'CNY',
      label: 'Chinese Yuan',
      locale: 'zh_CN',
      symbol: '¥',
      decimalDigits: 2,
      rateToIdr: 2150,
    ),
    CurrencyOption(
      code: 'JPY',
      label: 'Japanese Yen',
      locale: 'ja_JP',
      symbol: '¥',
      decimalDigits: 0,
      rateToIdr: 105,
    ),
    CurrencyOption(
      code: 'KRW',
      label: 'South Korean Won',
      locale: 'ko_KR',
      symbol: '₩',
      decimalDigits: 0,
      rateToIdr: 11.5,
    ),
    CurrencyOption(
      code: 'INR',
      label: 'Indian Rupee',
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
      rateToIdr: 186,
    ),
    CurrencyOption(
      code: 'AED',
      label: 'UAE Dirham',
      locale: 'ar_AE',
      symbol: 'AED',
      decimalDigits: 2,
      rateToIdr: 4220,
    ),
  ];

  static CurrencyOption _current = options.first;

  static CurrencyOption get current => _current;

  static Future<void> load({String? deviceLocaleTag}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_kCurrencyCode);
    if (savedCode != null && savedCode.isNotEmpty) {
      _current = byCode(savedCode) ?? options.first;
      return;
    }

    _current = byLocaleTag(deviceLocaleTag) ?? options.first;
  }

  static Future<void> setCurrencyCode(String code) async {
    final target = byCode(code) ?? options.first;
    _current = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrencyCode, target.code);
  }

  static CurrencyOption? byCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final item in options) {
      if (item.code == code) return item;
    }
    return null;
  }

  static CurrencyOption? byLocaleTag(String? localeTag) {
    if (localeTag == null || localeTag.isEmpty) return null;
    final normalized = localeTag.replaceAll('-', '_').toLowerCase();

    for (final item in options) {
      if (item.locale.toLowerCase() == normalized) return item;
    }

    final language = normalized.split('_').first;
    for (final item in options) {
      if (item.locale.toLowerCase().startsWith('${language}_')) return item;
    }
    return null;
  }

  static NumberFormat moneyFormatter({int? decimalDigits}) {
    return NumberFormat.currency(
      locale: _current.locale,
      symbol: _current.symbol,
      decimalDigits: decimalDigits ?? _current.decimalDigits,
    );
  }

  static double fromIdr(num amountIdr) {
    return amountIdr / _current.rateToIdr;
  }

  static double toIdr(num amountInCurrentCurrency) {
    return amountInCurrentCurrency * _current.rateToIdr;
  }

  static String formatFromCurrent(
    num amountInCurrentCurrency, {
    int? decimalDigits,
  }) {
    return moneyFormatter(
      decimalDigits: decimalDigits,
    ).format(amountInCurrentCurrency);
  }

  static String format(num amount, {int? decimalDigits}) {
    return moneyFormatter(decimalDigits: decimalDigits).format(fromIdr(amount));
  }

  static NumberFormat compactFormatter() {
    return NumberFormat.compactCurrency(
      locale: _current.locale,
      symbol: _current.symbol,
    );
  }

  static String formatCompact(num amount) {
    return compactFormatter().format(fromIdr(amount));
  }

  static NumberFormat decimalFormatter() {
    return NumberFormat.decimalPattern(_current.locale);
  }

  static String formatInputFromIdr(num amount) {
    final converted = fromIdr(amount);
    return decimalFormatter().format(converted.round());
  }

  static double parseInputToIdr(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return toIdr(double.parse(digits));
  }
}

class AppCurrencyNotifier extends Notifier<String> {
  @override
  String build() => CurrencySettings.current.code;

  Future<void> setCurrency(String code) async {
    await CurrencySettings.setCurrencyCode(code);
    state = CurrencySettings.current.code;
  }

  void refreshFromSettings() {
    state = CurrencySettings.current.code;
  }
}

final appCurrencyProvider = NotifierProvider<AppCurrencyNotifier, String>(() {
  return AppCurrencyNotifier();
});

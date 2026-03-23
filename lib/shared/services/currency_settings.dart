import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyOption {
  final String code;
  final String label;
  final String locale;
  final String symbol;
  final int decimalDigits;

  const CurrencyOption({
    required this.code,
    required this.label,
    required this.locale,
    required this.symbol,
    required this.decimalDigits,
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
    ),
    CurrencyOption(
      code: 'USD',
      label: 'US Dollar',
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ),
    CurrencyOption(
      code: 'EUR',
      label: 'Euro',
      locale: 'de_DE',
      symbol: '€',
      decimalDigits: 2,
    ),
    CurrencyOption(
      code: 'SGD',
      label: 'Singapore Dollar',
      locale: 'en_SG',
      symbol: 'S\$',
      decimalDigits: 2,
    ),
    CurrencyOption(
      code: 'JPY',
      label: 'Japanese Yen',
      locale: 'ja_JP',
      symbol: '¥',
      decimalDigits: 0,
    ),
  ];

  static CurrencyOption _current = options.first;

  static CurrencyOption get current => _current;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_kCurrencyCode);
    _current = byCode(savedCode) ?? options.first;
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

  static NumberFormat moneyFormatter({int? decimalDigits}) {
    return NumberFormat.currency(
      locale: _current.locale,
      symbol: _current.symbol,
      decimalDigits: decimalDigits ?? _current.decimalDigits,
    );
  }

  static String format(num amount, {int? decimalDigits}) {
    return moneyFormatter(decimalDigits: decimalDigits).format(amount);
  }

  static NumberFormat compactFormatter() {
    return NumberFormat.compactCurrency(
      locale: _current.locale,
      symbol: _current.symbol,
    );
  }

  static NumberFormat decimalFormatter() {
    return NumberFormat.decimalPattern(_current.locale);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageOption {
  final String code;
  final String label;
  final Locale locale;

  const LanguageOption({
    required this.code,
    required this.label,
    required this.locale,
  });
}

class LanguageSettings {
  static const _kLanguageCode = 'settings_language_code';

  static const options = <LanguageOption>[
    LanguageOption(code: 'en', label: 'English', locale: Locale('en', 'US')),
    LanguageOption(
      code: 'id',
      label: 'Bahasa Indonesia',
      locale: Locale('id', 'ID'),
    ),
  ];

  static LanguageOption _current = options.first;

  static LanguageOption get current => _current;

  static List<Locale> get supportedLocales =>
      options.map((e) => e.locale).toList(growable: false);

  static Future<void> load({Locale? deviceLocale}) async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_kLanguageCode);

    if (savedCode != null && savedCode.isNotEmpty) {
      _current = byCode(savedCode) ?? options.first;
      return;
    }

    final mappedFromDevice = byLocale(deviceLocale);
    _current = mappedFromDevice ?? options.first;
  }

  static Future<void> setLanguageCode(String code) async {
    final target = byCode(code) ?? options.first;
    _current = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageCode, target.code);
  }

  static LanguageOption? byCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final item in options) {
      if (item.code == code) return item;
    }
    return null;
  }

  static LanguageOption? byLocale(Locale? locale) {
    if (locale == null) return null;

    for (final item in options) {
      final l = item.locale;
      if (l.languageCode == locale.languageCode &&
          l.countryCode == locale.countryCode) {
        return item;
      }
    }

    for (final item in options) {
      if (item.locale.languageCode == locale.languageCode) {
        return item;
      }
    }
    return null;
  }
}

class AppLanguageNotifier extends Notifier<Locale> {
  @override
  Locale build() => LanguageSettings.current.locale;

  Future<void> setLanguage(String code) async {
    await LanguageSettings.setLanguageCode(code);
    state = LanguageSettings.current.locale;
  }

  void refreshFromSettings() {
    state = LanguageSettings.current.locale;
  }
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, Locale>(() {
  return AppLanguageNotifier();
});

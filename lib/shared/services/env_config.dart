import 'package:flutter/services.dart';

class EnvConfig {
  EnvConfig._();

  static final Map<String, String> _values = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('.env');
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final idx = trimmed.indexOf('=');
        if (idx <= 0) continue;
        final key = trimmed.substring(0, idx).trim();
        final value = trimmed.substring(idx + 1).trim();
        if (key.isEmpty) continue;
        _values[key] = value;
      }
    } catch (_) {
      // Keep empty env map when local .env is unavailable.
    }
    _loaded = true;
  }

  static String get(String key, {String fallback = ''}) {
    final value = _values[key];
    if (value == null || value.isEmpty) return fallback;
    return value;
  }
}

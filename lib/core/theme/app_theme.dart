import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- COLOR CONSTANTS ---
const Color _primaryDark = Color(0xFF0A0A0F);
const Color _surfaceDark = Color(0xFF141420);
const Color _cardDark = Color(0xFF1C1C2E);
const Color _accentBlue = Color(0xFF4F6EF7);
const Color _accentEmerald = Color(0xFF00D4AA);

class AppTheme {
  // --- DARK THEME (Tema Utama) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: _accentBlue,
        secondary: _accentEmerald,
        surface: _surfaceDark,
        error: Colors.redAccent,
      ),
      // Menggunakan Google Fonts: Inter
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),

      // Styling Komponen Global
      cardTheme: CardThemeData(
        color: _cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // 16px cards
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // 12px buttons
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // 8px chips
        ),
      ),
    );
  }

  // --- LIGHT THEME (Sebagai pelengkap toggle) ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F7FC),
      colorScheme: const ColorScheme.light(
        primary: _accentBlue,
        secondary: _accentEmerald,
        surface: Color(0xFFFFFFFF),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1A1E2A),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// --- STATE MANAGEMENT TEMA DENGAN RIVERPOD ---
// Notifier untuk menyimpan state apakah sedang Dark Mode atau tidak
class ThemeNotifier extends Notifier<ThemeMode> {
  static const _kThemeMode = 'app_theme_mode';
  bool _didHydrate = false;

  @override
  ThemeMode build() {
    _hydrate();
    return ThemeMode.dark;
  }

  Future<void> _hydrate() async {
    if (_didHydrate) return;
    _didHydrate = true;
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_kThemeMode);
    if (mode == 'light') {
      state = ThemeMode.light;
    } else if (mode == 'dark') {
      state = ThemeMode.dark;
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemeMode,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  void toggleTheme() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    _persist(next);
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _persist(mode);
  }
}

// Provider yang akan di-consume oleh main.dart
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

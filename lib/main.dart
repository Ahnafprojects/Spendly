import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'shared/services/notification_service.dart';

const _fallbackSupabaseUrl = 'https://bmnwttcpnfadbauwodxl.supabase.co';
const _fallbackSupabaseAnonKey = 'sb_publishable_Sl4O6c1z2s6PN-UHnOLybg_kKBrOI9Q';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _fallbackSupabaseUrl,
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _fallbackSupabaseAnonKey,
  );

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await initializeDateFormatting('id_ID');

  await NotificationService.initialize();

  // Nanti inisialisasi Local DB (Drift) akan diletakkan di sini.

  runApp(
    // ProviderScope wajib ada di paling atas untuk mengaktifkan Riverpod
    const ProviderScope(
      child: SpendlyApp(),
    ),
  );
}

// Menggunakan ConsumerWidget dari Riverpod untuk mendengarkan perubahan state
class SpendlyApp extends ConsumerWidget {
  const SpendlyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Membaca state router dan tema dari provider yang sudah kita buat
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Spendly',
      debugShowCheckedModeBanner: false,
      
      // Konfigurasi Tema
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode, // Menggunakan state dari ThemeNotifier

      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // Konfigurasi Navigasi GoRouter
      routerConfig: router,
    );
  }
}

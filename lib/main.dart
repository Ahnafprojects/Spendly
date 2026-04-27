import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'shared/services/currency_settings.dart';
import 'shared/services/env_config.dart';
import 'shared/services/language_settings.dart';
import 'shared/services/notification_service.dart';

const _fallbackSupabaseUrl = 'https://bmnwttcpnfadbauwodxl.supabase.co';
const _fallbackSupabaseAnonKey =
    'sb_publishable_Sl4O6c1z2s6PN-UHnOLybg_kKBrOI9Q';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _fallbackSupabaseUrl,
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _fallbackSupabaseAnonKey,
  );

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  await initializeDateFormatting();
  await LanguageSettings.load(deviceLocale: PlatformDispatcher.instance.locale);
  await CurrencySettings.load(
    deviceLocaleTag: PlatformDispatcher.instance.locale.toLanguageTag(),
  );

  await NotificationService.initialize();

  // Nanti inisialisasi Local DB (Drift) akan diletakkan di sini.

  runApp(
    // ProviderScope wajib ada di paling atas untuk mengaktifkan Riverpod
    const ProviderScope(child: SpendlyApp()),
  );
}

class SpendlyApp extends ConsumerStatefulWidget {
  const SpendlyApp({super.key});

  @override
  ConsumerState<SpendlyApp> createState() => _SpendlyAppState();
}

class _SpendlyAppState extends ConsumerState<SpendlyApp> {
  StreamSubscription<String>? _notificationRouteSub;

  @override
  void initState() {
    super.initState();
    _notificationRouteSub = NotificationService.routeTapStream.listen((route) {
      if (!mounted) return;
      ref.read(routerProvider).go(route);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialRoute = NotificationService.takeInitialRoute();
      if (initialRoute != null && mounted) {
        ref.read(routerProvider).go(initialRoute);
      }
    });
  }

  @override
  void dispose() {
    _notificationRouteSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Membaca state router dan tema dari provider yang sudah kita buat
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    final appLocale = ref.watch(appLanguageProvider);
    ref.watch(appCurrencyProvider);

    return MaterialApp.router(
      title: 'Spendly',
      debugShowCheckedModeBanner: false,

      // Konfigurasi Tema
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode, // Menggunakan state dari ThemeNotifier

      locale: appLocale,
      supportedLocales: LanguageSettings.supportedLocales,
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

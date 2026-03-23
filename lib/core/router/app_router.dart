import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/transaction/screens/add_transaction_screen.dart';
import '../../features/transaction/screens/transaction_history_screen.dart';
import '../../features/transfer/screens/transfer_screen.dart';
import '../../shared/models/transaction_model.dart';

// Provider untuk Router agar mudah diakses secara global
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/add-transaction',
        name: 'add-transaction',
        builder: (context, state) => AddTransactionScreen(
          initialTransaction: state.extra is TransactionModel
              ? state.extra as TransactionModel
              : null,
        ),
      ),
      GoRoute(
        path: '/transactions',
        name: 'transactions',
        builder: (context, state) => const TransactionHistoryScreen(),
      ),
      GoRoute(
        path: '/transfer',
        name: 'transfer',
        builder: (context, state) => const TransferScreen(),
      ),
      GoRoute(
        path: '/analytics',
        name: 'analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/budget',
        name: 'budget',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

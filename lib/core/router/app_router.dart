import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/auth/screens/auth_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/navigation/screens/main_tab_screen.dart';
import '../../features/savings/screens/savings_screen.dart';
import '../../features/spaces/screens/activity_feed_screen.dart';
import '../../features/spaces/screens/invite_screen.dart';
import '../../features/spaces/screens/members_screen.dart';
import '../../features/transaction/screens/add_transaction_screen.dart';
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
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainTabScreen(currentIndex: 0),
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
        builder: (context, state) => const MainTabScreen(currentIndex: 1),
      ),
      GoRoute(
        path: '/transfer',
        name: 'transfer',
        builder: (context, state) => const SavingsScreen(),
      ),
      GoRoute(
        path: '/analytics',
        name: 'analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/accounts',
        name: 'accounts',
        builder: (context, state) => const MainTabScreen(currentIndex: 2),
      ),
      GoRoute(
        path: '/budget',
        name: 'budget',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const MainTabScreen(currentIndex: 3),
      ),
      GoRoute(
        path: '/members',
        name: 'members',
        builder: (context, state) => const MembersScreen(),
      ),
      GoRoute(
        path: '/invite-member',
        name: 'invite-member',
        builder: (context, state) => const InviteScreen(),
      ),
      GoRoute(
        path: '/invitation-inbox',
        name: 'invitation-inbox',
        builder: (context, state) => const InviteScreen(inboxMode: true),
      ),
      GoRoute(
        path: '/space-activity',
        name: 'space-activity',
        builder: (context, state) => const ActivityFeedScreen(),
      ),
    ],
  );
});

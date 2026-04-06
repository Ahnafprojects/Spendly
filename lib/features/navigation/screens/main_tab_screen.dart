import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/app_text.dart';
import '../../../shared/services/invitation_service.dart';
import '../../account/screens/accounts_overview_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../transaction/screens/transaction_history_screen.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  final int currentIndex;

  const MainTabScreen({super.key, required this.currentIndex});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  bool _invitationChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_invitationChecked || widget.currentIndex != 0 || !mounted) return;
      _invitationChecked = true;
      try {
        await ref
            .read(invitationServiceProvider)
            .promptPendingInvitations(context, ref);
      } catch (_) {
        // Keep dashboard usable even if invitation check fails.
      }
    });
  }

  void _onTap(BuildContext context, int index) {
    if (index == widget.currentIndex) return;
    if (index == 0) {
      context.go('/dashboard');
      return;
    }
    if (index == 1) {
      context.go('/transactions');
      return;
    }
    if (index == 2) {
      context.go('/accounts');
      return;
    }
    context.go('/settings');
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(),
      const TransactionHistoryScreen(),
      const AccountsOverviewScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: widget.currentIndex, children: pages),
      bottomNavigationBar: _MainBottomBar(
        currentIndex: widget.currentIndex,
        onTap: (index) => _onTap(context, index),
      ),
    );
  }
}

class _MainBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MainBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101727) : Colors.white;
    final border = isDark ? Colors.white10 : const Color(0xFFDCE5FA);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : const Color(0xFF9CB0DA).withValues(alpha: 0.24);

    final items = [
      (icon: Icons.home_rounded, label: AppText.t(id: 'Home', en: 'Home')),
      (
        icon: Icons.receipt_long_rounded,
        label: AppText.t(id: 'Transaksi', en: 'Transactions'),
      ),
      (
        icon: Icons.account_balance_wallet_rounded,
        label: AppText.t(id: 'Akun', en: 'Accounts'),
      ),
      (
        icon: Icons.settings_rounded,
        label: AppText.t(id: 'Pengaturan', en: 'Settings'),
      ),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = currentIndex == index;
              return Expanded(
                child: _BottomTabItem(
                  icon: item.icon,
                  label: item.label,
                  selected: selected,
                  isDark: isDark,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _BottomTabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF4F6EF7);
    final textColor = selected
        ? active
        : (isDark ? Colors.white70 : const Color(0xFF5B6275));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? active.withValues(alpha: isDark ? 0.2 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

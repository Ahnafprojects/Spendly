import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../account_model.dart';
import '../../../shared/widgets/app_notice.dart';
import '../account_notifier.dart';
import 'add_account_sheet.dart';

class AccountSwitcherWidget extends ConsumerWidget {
  const AccountSwitcherWidget({super.key});
  String _t(String id, String en) => AppText.t(id: id, en: en);

  Future<void> _showResultNotice(
    BuildContext context,
    AddAccountSheetResult result,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!context.mounted) return;
    if (result.action == AddAccountAction.added) {
      AppNotice.success(
        context,
        '${_t('Akun berhasil ditambahkan', 'Account added successfully')}: ${result.accountName}',
      );
    } else if (result.action == AddAccountAction.updated) {
      AppNotice.success(
        context,
        '${_t('Akun berhasil diperbarui', 'Account updated successfully')}: ${result.accountName}',
      );
    } else {
      AppNotice.success(
        context,
        '${_t('Akun berhasil dihapus', 'Account deleted successfully')}: ${result.accountName}',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(accountNotifierProvider);
    final activeId = ref.watch(activeAccountIdProvider);
    final balancesState = ref.watch(accountBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 98,
      child: accountsState.when(
        data: (accounts) {
          final balances =
              balancesState.valueOrNull ?? const <String, double>{};
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              if (index == accounts.length) {
                return _AddAccountCard(
                  onTap: () async {
                    final result =
                        await showModalBottomSheet<AddAccountSheetResult>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const AddAccountSheet(),
                        );
                    if (result == null || !context.mounted) return;
                    await _showResultNotice(context, result);
                  },
                );
              }
              final account = accounts[index];
              final selected = account.id == activeId;
              final balance = balances[account.id] ?? account.initialBalance;
              return GestureDetector(
                onTap: () => ref
                    .read(accountNotifierProvider.notifier)
                    .switchAccount(account.id),
                child: AnimatedScale(
                  scale: selected ? 1.03 : 0.96,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isDark
                                ? const Color(0xFF22283C)
                                : const Color(0xFFEFF3FF))
                          : const Color(0xFF1C1C2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? (isDark
                                  ? Colors.white24
                                  : const Color(0xFFD2DBF3))
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: account.colorValue.withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            accountIconData(account.icon),
                            size: 15,
                            color: account.colorValue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencySettings.formatCompact(balance),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF99AEFF)
                                : Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '${_t('Gagal memuat akun', 'Failed to load accounts')}: $e',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _AddAccountCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAccountCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C1C2E), Color(0xFF24243A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: Color(0xFF4F6EF7),
              ),
              const SizedBox(width: 6),
              Text(
                AppText.t(id: 'Akun', en: 'Account'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

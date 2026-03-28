import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/app_text.dart';
import '../../../shared/services/currency_settings.dart';
import '../../../shared/widgets/app_notice.dart';
import '../account_model.dart';
import '../account_notifier.dart';
import '../widgets/add_account_sheet.dart';

class AccountsOverviewScreen extends ConsumerWidget {
  const AccountsOverviewScreen({super.key});
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
    final accountState = ref.watch(accountNotifierProvider);
    final balanceState = ref.watch(accountBalancesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090B14) : const Color(0xFFF4F7FC);
    final card = isDark ? const Color(0xFF151A2A) : Colors.white;
    final title = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(_t('Semua Akun', 'All Accounts')),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F6EF7),
        onPressed: () async {
          final result = await showModalBottomSheet<AddAccountSheetResult>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddAccountSheet(),
          );
          if (result == null || !context.mounted) return;
          await _showResultNotice(context, result);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: accountState.when(
          data: (accounts) {
            final balances =
                balanceState.valueOrNull ?? const <String, double>{};
            final total = balances.values.fold<double>(0, (sum, v) => sum + v);
            if (accounts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 72,
                        color: muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('Belum ada akun', 'No accounts yet'),
                        style: TextStyle(
                          color: title,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'Tambahkan akun pertama kamu untuk mulai tracking saldo per dompet.',
                          'Add your first account to start tracking balance by wallet.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F6EF7), Color(0xFF00D4AA)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('Total Kekayaan Bersih', 'Total Net Worth'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: total),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Text(
                            CurrencySettings.format(value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _t('Daftar Akun', 'Account List'),
                  style: TextStyle(
                    color: title,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                ...accounts.map((account) {
                  final balance = balances[account.id] ?? 0;
                  final pct = total == 0
                      ? 0.0
                      : (balance / total).clamp(0.0, 1.0).toDouble();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey(account.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(
                        context,
                        ref,
                        account: account,
                        balance: balance,
                      ),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _t('Hapus', 'Delete'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      child: InkWell(
                        onTap: () async {
                          await ref
                              .read(accountNotifierProvider.notifier)
                              .switchAccount(account.id);
                          if (!context.mounted) return;
                          context.go('/transactions');
                        },
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        overlayColor: const WidgetStatePropertyAll<Color>(
                          Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : const Color(0xFFDDE5F7),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: account.colorValue.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    child: Icon(
                                      accountIconData(account.icon),
                                      size: 18,
                                      color: account.colorValue,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          account.name,
                                          style: TextStyle(
                                            color: title,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          accountTypeLabel(
                                            account.type,
                                            isEnglish: AppText.isEnglish,
                                          ),
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencySettings.formatCompact(balance),
                                    style: TextStyle(
                                      color: title,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      final result =
                                          await showModalBottomSheet<
                                            AddAccountSheetResult
                                          >(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) => AddAccountSheet(
                                              initial: account,
                                            ),
                                          );
                                      if (result == null || !context.mounted) {
                                        return;
                                      }
                                      await _showResultNotice(context, result);
                                    },
                                    tooltip: _t('Edit akun', 'Edit account'),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF4F6EF7),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(999),
                                backgroundColor: isDark
                                    ? const Color(0xFF1F2942)
                                    : const Color(0xFFE9EEFA),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  account.colorValue,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(pct * 100).toStringAsFixed(1)} ${_t('dari total', 'of total')}',
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              '${_t('Gagal memuat akun', 'Failed to load accounts')}: $e',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    WidgetRef ref, {
    required AccountModel account,
    required double balance,
  }) async {
    if (balance.abs() > 0.0001) {
      AppNotice.warning(
        context,
        _t(
          'Saldo akun harus 0 untuk dihapus',
          'Account balance must be 0 to delete',
        ),
      );
      return false;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Hapus akun?', 'Delete account?')),
        content: Text(
          _t(
            'Akun "${account.name}" akan dihapus permanen.',
            'Account "${account.name}" will be deleted permanently.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Hapus', 'Delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref
            .read(accountNotifierProvider.notifier)
            .deleteIfZeroBalance(account.id);
        if (context.mounted) {
          AppNotice.success(context, _t('Akun dihapus', 'Account deleted'));
        }
        return true;
      } catch (e) {
        if (context.mounted) {
          AppNotice.error(context, '$e');
        }
      }
    }
    return false;
  }
}

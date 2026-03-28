import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_notifier.dart';
import '../budget/budget_notifier.dart';
import '../transaction/transaction_notifier.dart';
import '../../shared/services/app_text.dart';
import 'account_model.dart';
import 'account_repository.dart';

const _activeAccountKey = 'active_account_id_v1';

final activeAccountIdProvider = StateProvider<String?>((ref) => null);

final activeAccountProvider = Provider<AccountModel?>((ref) {
  final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
  final activeId = ref.watch(activeAccountIdProvider);
  if (accounts.isEmpty) return null;
  if (activeId == null) return accounts.first;
  return accounts.firstWhere(
    (a) => a.id == activeId,
    orElse: () => accounts.first,
  );
});

final accountBalancesProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final repo = ref.watch(accountRepositoryProvider);
  final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
  final result = <String, double>{};
  for (final account in accounts) {
    result[account.id] = await repo.getBalance(account.id);
  }
  return result;
});

class AccountNotifier extends AsyncNotifier<List<AccountModel>> {
  late AccountRepository _repository;

  @override
  FutureOr<List<AccountModel>> build() async {
    _repository = ref.watch(accountRepositoryProvider);
    final accounts = await _repository.fetchAll();
    final resolved = await _ensureDefaultAccount(accounts);
    await _hydrateActiveAccount(resolved);
    return resolved;
  }

  Future<List<AccountModel>> _ensureDefaultAccount(
    List<AccountModel> current,
  ) async {
    if (current.isNotEmpty) return current;
    final now = DateTime.now();
    await _repository.insert(
      AccountModel(
        id: '',
        userId: '',
        name: AppText.t(id: 'Tunai', en: 'Cash'),
        type: 'cash',
        icon: '💵',
        color: '#4F6EF7',
        initialBalance: 0,
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return _repository.fetchAll();
  }

  Future<void> _hydrateActiveAccount(List<AccountModel> accounts) async {
    if (accounts.isEmpty) {
      ref.read(activeAccountIdProvider.notifier).state = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_activeAccountKey);
    final found = accounts.any((a) => a.id == saved);
    final selected = found
        ? saved!
        : (accounts
              .firstWhere((a) => a.isDefault, orElse: () => accounts.first)
              .id);
    ref.read(activeAccountIdProvider.notifier).state = selected;
    await prefs.setString(_activeAccountKey, selected);
  }

  Future<void> switchAccount(String id) async {
    ref.read(activeAccountIdProvider.notifier).state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeAccountKey, id);
    ref.invalidate(transactionNotifierProvider);
    ref.invalidate(budgetNotifierProvider);
    ref.invalidate(analyticsNotifierProvider);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final accounts = await _repository.fetchAll();
      await _hydrateActiveAccount(accounts);
      return accounts;
    });
    ref.invalidate(accountBalancesProvider);
  }

  Future<void> add(AccountModel account) async {
    final inserted = await _repository.insert(account);
    await reload();
    await switchAccount(inserted.id);
  }

  Future<void> updateAccount(AccountModel account) async {
    await _repository.update(account);
    await reload();
  }

  Future<void> deleteIfZeroBalance(String accountId) async {
    final current = state.valueOrNull ?? const <AccountModel>[];
    if (current.length <= 1) {
      throw Exception(
        AppText.t(
          id: 'Minimal harus ada satu akun',
          en: 'At least one account must remain',
        ),
      );
    }
    final balance = await _repository.getBalance(accountId);
    if (balance.abs() > 0.0001) {
      throw Exception(
        AppText.t(
          id: 'Akun hanya bisa dihapus jika saldo 0',
          en: 'Account can be deleted only when balance is 0',
        ),
      );
    }
    await _repository.delete(accountId);

    var accounts = await _repository.fetchAll();
    final hasDefault = accounts.any((a) => a.isDefault);
    if (accounts.isNotEmpty && !hasDefault) {
      final first = accounts.first.copyWith(isDefault: true);
      await _repository.update(first);
      accounts = await _repository.fetchAll();
    }
    state = AsyncData(accounts);
    ref.invalidate(accountBalancesProvider);

    final currentActive = ref.read(activeAccountIdProvider);
    if (currentActive == accountId) {
      final nextId = accounts.isEmpty ? null : accounts.first.id;
      ref.read(activeAccountIdProvider.notifier).state = nextId;
      final prefs = await SharedPreferences.getInstance();
      if (nextId == null) {
        await prefs.remove(_activeAccountKey);
      } else {
        await prefs.setString(_activeAccountKey, nextId);
      }
    }
  }
}

final accountNotifierProvider =
    AsyncNotifierProvider<AccountNotifier, List<AccountModel>>(
      () => AccountNotifier(),
    );

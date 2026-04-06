import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/app_text.dart';
import '../../shared/services/offline_store.dart';
import 'account_model.dart';

class AccountWithBalance {
  final AccountModel account;
  final double balance;

  const AccountWithBalance({required this.account, required this.balance});
}

class AccountRepository {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;

  AccountRepository({
    SupabaseClient? supabase,
    required OfflineStore offlineStore,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _offlineStore = offlineStore;

  Future<String> _resolveUserId() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.isNotEmpty) {
      await _offlineStore.saveLastUserId(authId);
      return authId;
    }
    final cached = await _offlineStore.readLastUserId();
    if (cached != null && cached.isNotEmpty) return cached;
    throw Exception('User belum login');
  }

  String _generateUuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).toList();
    return '${b[0]}${b[1]}${b[2]}${b[3]}-'
        '${b[4]}${b[5]}-'
        '${b[6]}${b[7]}-'
        '${b[8]}${b[9]}-'
        '${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }

  Future<List<AccountModel>> fetchAll({String? spaceId}) async {
    final userId = await _resolveUserId();
    var query = _supabase.from('accounts').select();
    query = spaceId == null
        ? query.eq('user_id', userId).isFilter('space_id', null)
        : query.eq('space_id', spaceId);
    final response = await query
        .order('is_default', ascending: false)
        .order('created_at', ascending: true);
    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(AccountModel.fromJson)
        .toList();
  }

  Future<AccountModel> insert(AccountModel account, {String? spaceId}) async {
    final userId = await _resolveUserId();
    final accountName = account.name.trim();
    var existingQuery = _supabase
        .from('accounts')
        .select('id')
        .ilike('name', accountName);
    existingQuery = spaceId == null
        ? existingQuery.eq('user_id', userId).isFilter('space_id', null)
        : existingQuery.eq('space_id', spaceId);
    final existing = await existingQuery.limit(1);
    if ((existing as List).isNotEmpty) {
      throw Exception(
        AppText.t(
          id: 'Nama akun sudah dipakai',
          en: 'Account name is already used',
        ),
      );
    }
    if (account.isDefault) {
      var defaultQuery = _supabase.from('accounts').update({
        'is_default': false,
      });
      defaultQuery = spaceId == null
          ? defaultQuery.eq('user_id', userId).isFilter('space_id', null)
          : defaultQuery.eq('space_id', spaceId);
      await defaultQuery;
    }
    final row = account.toJson()
      ..['id'] = account.id.isEmpty ? _generateUuidV4() : account.id
      ..['name'] = accountName
      ..['user_id'] = userId
      ..['space_id'] = spaceId;
    final inserted = await _supabase
        .from('accounts')
        .insert(row)
        .select()
        .single();
    return AccountModel.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<void> update(AccountModel account, {String? spaceId}) async {
    final userId = await _resolveUserId();
    if (account.isDefault) {
      var clearDefault = _supabase
          .from('accounts')
          .update({'is_default': false})
          .neq('id', account.id);
      clearDefault = spaceId == null
          ? clearDefault.eq('user_id', userId).isFilter('space_id', null)
          : clearDefault.eq('space_id', spaceId);
      await clearDefault;
    }
    var update = _supabase
        .from('accounts')
        .update(account.toJson())
        .eq('id', account.id);
    update = spaceId == null
        ? update.eq('user_id', userId).isFilter('space_id', null)
        : update.eq('space_id', spaceId);
    await update;
  }

  Future<void> delete(String accountId, {String? spaceId}) async {
    final userId = await _resolveUserId();
    var query = _supabase.from('accounts').delete().eq('id', accountId);
    query = spaceId == null
        ? query.eq('user_id', userId).isFilter('space_id', null)
        : query.eq('space_id', spaceId);
    await query;
  }

  Future<double> getBalance(String accountId) async {
    final response = await _supabase.rpc(
      'get_account_balance',
      params: {'p_account_id': accountId},
    );
    return (response as num?)?.toDouble() ?? 0;
  }

  Future<List<AccountWithBalance>> fetchAllWithBalances({
    String? spaceId,
  }) async {
    final accounts = await fetchAll(spaceId: spaceId);
    final withBalances = <AccountWithBalance>[];
    for (final account in accounts) {
      final balance = await getBalance(account.id);
      withBalances.add(AccountWithBalance(account: account, balance: balance));
    }
    return withBalances;
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(offlineStore: OfflineStore());
});

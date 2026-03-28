import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/transaction_model.dart';
import '../../shared/services/offline_store.dart';

class TransactionRepository {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;

  TransactionRepository({
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

  bool get _canHitRemote => _supabase.auth.currentUser != null;

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

  Future<void> _syncPendingOps(String userId) async {
    final ops = await _offlineStore.readPendingTxOps(userId);
    if (ops.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    for (final op in ops) {
      try {
        final type = (op['op'] ?? '').toString();
        final payload = Map<String, dynamic>.from(op['payload'] as Map);
        if (type == 'upsert') {
          await _supabase
              .from('transactions')
              .upsert(payload, onConflict: 'id');
        } else if (type == 'delete') {
          await _supabase
              .from('transactions')
              .delete()
              .eq('id', (payload['id'] ?? '').toString())
              .eq('user_id', userId);
        } else {
          remaining.add(op);
        }
      } catch (_) {
        remaining.add(op);
      }
    }

    await _offlineStore.writePendingTxOps(userId, remaining);
  }

  // Mengambil 10 transaksi terakhir user
  Future<List<TransactionModel>> fetchRecent({
    int limit = 10,
    String? accountId,
  }) async {
    final userId = await _resolveUserId();

    try {
      if (_canHitRemote) {
        await _syncPendingOps(userId);
      }
      var query = _supabase.from('transactions').select().eq('user_id', userId);
      if (accountId != null) {
        query = query.eq('account_id', accountId);
      }
      final response = await query.order('date', ascending: false).limit(limit);
      final rows = (response as List).cast<Map<String, dynamic>>();
      await _offlineStore.writeTransactions(userId, rows);
      return rows.map(TransactionModel.fromJson).toList();
    } catch (_) {
      final local = await _offlineStore.readTransactions(userId);
      final localFiltered = accountId == null
          ? local
          : local
                .where((tx) => (tx['account_id'] ?? '').toString() == accountId)
                .toList();
      localFiltered.sort((a, b) {
        final ad =
            DateTime.tryParse((a['date'] ?? '').toString()) ?? DateTime(1970);
        final bd =
            DateTime.tryParse((b['date'] ?? '').toString()) ?? DateTime(1970);
        return bd.compareTo(ad);
      });
      return localFiltered.take(limit).map(TransactionModel.fromJson).toList();
    }
  }

  // Mengambil SEMUA transaksi user
  Future<List<TransactionModel>> fetchAll({String? accountId}) async {
    final userId = await _resolveUserId();

    try {
      if (_canHitRemote) {
        await _syncPendingOps(userId);
      }
      var query = _supabase.from('transactions').select().eq('user_id', userId);
      if (accountId != null) {
        query = query.eq('account_id', accountId);
      }
      final response = await query.order('date', ascending: false);
      final rows = (response as List).cast<Map<String, dynamic>>();
      await _offlineStore.writeTransactions(userId, rows);
      return rows.map(TransactionModel.fromJson).toList();
    } catch (_) {
      final local = await _offlineStore.readTransactions(userId);
      final localFiltered = accountId == null
          ? local
          : local
                .where((tx) => (tx['account_id'] ?? '').toString() == accountId)
                .toList();
      localFiltered.sort((a, b) {
        final ad =
            DateTime.tryParse((a['date'] ?? '').toString()) ?? DateTime(1970);
        final bd =
            DateTime.tryParse((b['date'] ?? '').toString()) ?? DateTime(1970);
        return bd.compareTo(ad);
      });
      return localFiltered.map(TransactionModel.fromJson).toList();
    }
  }

  // Menambahkan transaksi baru
  Future<void> insert(TransactionModel transaction) async {
    final userId = await _resolveUserId();

    final row = transaction.toJson()
      ..['id'] = transaction.id.isEmpty ? _generateUuidV4() : transaction.id
      ..['user_id'] = userId
      ..['created_at'] = transaction.createdAt.toIso8601String();

    await _offlineStore.upsertTransaction(userId, row);
    if (!_canHitRemote) {
      await _offlineStore.enqueuePendingTxOp(userId, 'upsert', row);
      return;
    }
    try {
      await _supabase.from('transactions').upsert(row, onConflict: 'id');
    } catch (_) {
      await _offlineStore.enqueuePendingTxOp(userId, 'upsert', row);
    }
  }

  // Memperbarui transaksi yang sudah ada
  Future<void> update(TransactionModel transaction) async {
    final userId = await _resolveUserId();

    final row = transaction.toJson()..['user_id'] = userId;
    await _offlineStore.upsertTransaction(userId, row);
    if (!_canHitRemote) {
      await _offlineStore.enqueuePendingTxOp(userId, 'upsert', row);
      return;
    }
    try {
      await _supabase.from('transactions').upsert(row, onConflict: 'id');
    } catch (_) {
      await _offlineStore.enqueuePendingTxOp(userId, 'upsert', row);
    }
  }

  // Menghapus transaksi
  Future<void> delete(String id) async {
    final userId = await _resolveUserId();

    await _offlineStore.deleteTransaction(userId, id);
    if (!_canHitRemote) {
      await _offlineStore.enqueuePendingTxOp(userId, 'delete', {'id': id});
      return;
    }
    try {
      await _supabase
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (_) {
      await _offlineStore.enqueuePendingTxOp(userId, 'delete', {'id': id});
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(offlineStore: OfflineStore());
});

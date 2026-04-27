import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineStore {
  static const _kLastUserId = 'offline_last_user_id';
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  String _txKey(String userId) => 'offline_transactions_$userId';
  String _budgetKey(String userId) => 'offline_budgets_$userId';
  String _txOpsKey(String userId) => 'offline_tx_ops_$userId';
  String _budgetOpsKey(String userId) => 'offline_budget_ops_$userId';
  String _receiptMetaKey(String userId) => 'offline_receipt_meta_$userId';

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _encodeList(List<Map<String, dynamic>> data) => jsonEncode(data);

  Future<List<Map<String, dynamic>>> readTransactions(String userId) async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_txKey(userId)));
  }

  Future<void> writeTransactions(
    String userId,
    List<Map<String, dynamic>> data,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_txKey(userId), _encodeList(data));
  }

  Future<void> upsertTransaction(String userId, Map<String, dynamic> tx) async {
    final data = await readTransactions(userId);
    final id = (tx['id'] ?? '').toString();
    final idx = data.indexWhere((e) => (e['id'] ?? '').toString() == id);
    if (idx >= 0) {
      data[idx] = tx;
    } else {
      data.add(tx);
    }
    await writeTransactions(userId, data);
  }

  Future<void> deleteTransaction(String userId, String id) async {
    final data = await readTransactions(userId);
    data.removeWhere((e) => (e['id'] ?? '').toString() == id);
    await writeTransactions(userId, data);
  }

  Future<List<Map<String, dynamic>>> readBudgets(String userId) async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_budgetKey(userId)));
  }

  Future<void> writeBudgets(
    String userId,
    List<Map<String, dynamic>> data,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_budgetKey(userId), _encodeList(data));
  }

  Future<void> upsertBudget(String userId, Map<String, dynamic> budget) async {
    final data = await readBudgets(userId);
    final category = (budget['category'] ?? '').toString();
    final month = (budget['month'] ?? '').toString();
    final idx = data.indexWhere(
      (e) =>
          (e['category'] ?? '').toString() == category &&
          (e['month'] ?? '').toString() == month,
    );
    if (idx >= 0) {
      data[idx] = budget;
    } else {
      data.add(budget);
    }
    await writeBudgets(userId, data);
  }

  Future<void> deleteBudget(
    String userId,
    String category,
    String month,
  ) async {
    final data = await readBudgets(userId);
    data.removeWhere(
      (e) =>
          (e['category'] ?? '').toString() == category &&
          (e['month'] ?? '').toString() == month,
    );
    await writeBudgets(userId, data);
  }

  Future<List<Map<String, dynamic>>> readPendingTxOps(String userId) async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_txOpsKey(userId)));
  }

  Future<void> writePendingTxOps(
    String userId,
    List<Map<String, dynamic>> data,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_txOpsKey(userId), _encodeList(data));
  }

  Future<void> enqueuePendingTxOp(
    String userId,
    String op,
    Map<String, dynamic> payload,
  ) async {
    final ops = await readPendingTxOps(userId);
    ops.add({'op': op, 'payload': payload});
    await writePendingTxOps(userId, ops);
  }

  Future<List<Map<String, dynamic>>> readPendingBudgetOps(String userId) async {
    final prefs = await _prefs;
    return _decodeList(prefs.getString(_budgetOpsKey(userId)));
  }

  Future<void> writePendingBudgetOps(
    String userId,
    List<Map<String, dynamic>> data,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_budgetOpsKey(userId), _encodeList(data));
  }

  Future<void> enqueuePendingBudgetOp(
    String userId,
    String op,
    Map<String, dynamic> payload,
  ) async {
    final ops = await readPendingBudgetOps(userId);
    ops.add({'op': op, 'payload': payload});
    await writePendingBudgetOps(userId, ops);
  }

  Future<Map<String, Map<String, dynamic>>> readReceiptMetadata(
    String userId,
  ) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_receiptMetaKey(userId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{},
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> writeReceiptMetadata(
    String userId,
    Map<String, Map<String, dynamic>> data,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(_receiptMetaKey(userId), jsonEncode(data));
  }

  Future<void> saveReceiptMetadata(
    String userId,
    String transactionId,
    Map<String, dynamic> metadata,
  ) async {
    final current = await readReceiptMetadata(userId);
    current[transactionId] = metadata;
    await writeReceiptMetadata(userId, current);
  }

  Future<Map<String, dynamic>?> readReceiptMetadataForTransaction(
    String userId,
    String transactionId,
  ) async {
    final current = await readReceiptMetadata(userId);
    return current[transactionId];
  }

  Future<void> deleteReceiptMetadata(
    String userId,
    String transactionId,
  ) async {
    final current = await readReceiptMetadata(userId);
    current.remove(transactionId);
    await writeReceiptMetadata(userId, current);
  }

  Future<void> clearUserData(String userId) async {
    final prefs = await _prefs;
    await prefs.remove(_txKey(userId));
    await prefs.remove(_budgetKey(userId));
    await prefs.remove(_txOpsKey(userId));
    await prefs.remove(_budgetOpsKey(userId));
    await prefs.remove(_receiptMetaKey(userId));
  }

  Future<void> saveLastUserId(String userId) async {
    final prefs = await _prefs;
    await prefs.setString(_kLastUserId, userId);
  }

  Future<String?> readLastUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_kLastUserId);
  }
}

final offlineStoreProvider = Provider<OfflineStore>((ref) {
  return OfflineStore();
});

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/app_text.dart';

class TransferService {
  final SupabaseClient _supabase;

  TransferService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

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

  Future<void> transfer({
    required String fromId,
    required String toId,
    required double amount,
    String? note,
  }) async {
    if (fromId == toId) {
      throw Exception(
        AppText.t(
          id: 'Akun asal dan tujuan tidak boleh sama',
          en: 'Source and destination account must be different',
        ),
      );
    }
    if (amount <= 0) {
      throw Exception(
        AppText.t(
          id: 'Nominal harus lebih dari 0',
          en: 'Amount must be greater than 0',
        ),
      );
    }
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception(
        AppText.t(id: 'User belum login', en: 'User not logged in'),
      );
    }

    final now = DateTime.now();
    final groupId = _generateUuidV4();
    final cleanNote = (note ?? '').trim();

    final base = {
      'user_id': userId,
      'amount': amount,
      'type': 'transfer',
      'category': 'Transfer',
      'date': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'transfer_group_id': groupId,
    };

    final rows = [
      {
        ...base,
        'id': _generateUuidV4(),
        'account_id': fromId,
        'transfer_direction': 'out',
        'note': cleanNote.isEmpty
            ? AppText.t(id: 'Transfer keluar', en: 'Transfer out')
            : cleanNote,
      },
      {
        ...base,
        'id': _generateUuidV4(),
        'account_id': toId,
        'transfer_direction': 'in',
        'note': cleanNote.isEmpty
            ? AppText.t(id: 'Transfer masuk', en: 'Transfer in')
            : cleanNote,
      },
    ];

    await _supabase.from('transactions').insert(rows);
  }
}

final transferServiceProvider = Provider<TransferService>((ref) {
  return TransferService();
});

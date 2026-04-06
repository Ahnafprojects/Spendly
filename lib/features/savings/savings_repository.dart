import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/offline_store.dart';
import 'savings_deposit_model.dart';
import 'savings_goal_model.dart';

class SavingsRepository {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;

  SavingsRepository({
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

  Future<List<SavingsGoalModel>> fetchGoals({String? spaceId}) async {
    final userId = await _resolveUserId();
    var query = _supabase.from('savings_goals').select();
    query = spaceId == null
        ? query.eq('user_id', userId).isFilter('space_id', null)
        : query.eq('space_id', spaceId);
    final response = await query
        .order('is_completed', ascending: true)
        .order('target_date', ascending: true)
        .order('created_at', ascending: false);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(SavingsGoalModel.fromJson)
        .toList();
  }

  Future<SavingsGoalModel?> fetchGoalById(
    String goalId, {
    String? spaceId,
  }) async {
    final userId = await _resolveUserId();
    var query = _supabase.from('savings_goals').select().eq('id', goalId);
    query = spaceId == null
        ? query.eq('user_id', userId).isFilter('space_id', null)
        : query.eq('space_id', spaceId);
    final response = await query.maybeSingle();
    if (response == null) return null;
    return SavingsGoalModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<SavingsDepositModel>> fetchDeposits(
    String goalId, {
    String? spaceId,
  }) async {
    final userId = await _resolveUserId();
    var query = _supabase
        .from('savings_deposits')
        .select('*, profiles(full_name)')
        .eq('goal_id', goalId);
    query = spaceId == null ? query.eq('user_id', userId) : query;
    final response = await query.order('created_at', ascending: false);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(SavingsDepositModel.fromJson)
        .toList();
  }

  Future<SavingsGoalModel> createGoal(
    SavingsGoalModel goal, {
    String? spaceId,
  }) async {
    final userId = await _resolveUserId();
    _validateGoal(goal);

    final now = DateTime.now();
    final initialAmount = goal.currentAmount < 0 ? 0 : goal.currentAmount;

    final row = {
      'user_id': userId,
      'name': goal.name.trim(),
      'icon': normalizeSavingsGoalIcon(goal.icon),
      'color': goal.color,
      'space_id': spaceId,
      'target_amount': goal.targetAmount,
      'current_amount': initialAmount,
      'target_date': _dateOnly(goal.targetDate),
      'is_completed': initialAmount >= goal.targetAmount,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    final inserted = await _supabase
        .from('savings_goals')
        .insert(row)
        .select()
        .single();

    final created = SavingsGoalModel.fromJson(
      Map<String, dynamic>.from(inserted),
    );

    if (initialAmount > 0) {
      await _supabase.from('savings_deposits').insert({
        'goal_id': created.id,
        'user_id': userId,
        'amount': initialAmount,
        'note': 'Initial deposit',
      });
    }

    return created;
  }

  Future<SavingsGoalModel> updateGoal(
    SavingsGoalModel goal, {
    String? spaceId,
  }) async {
    final userId = await _resolveUserId();
    _validateGoal(goal);

    final row = {
      'name': goal.name.trim(),
      'icon': normalizeSavingsGoalIcon(goal.icon),
      'color': goal.color,
      'target_amount': goal.targetAmount,
      'target_date': _dateOnly(goal.targetDate),
      'is_completed': goal.currentAmount >= goal.targetAmount,
      'updated_at': DateTime.now().toIso8601String(),
    };

    var query = _supabase.from('savings_goals').update(row).eq('id', goal.id);
    query = spaceId == null
        ? query.eq('user_id', userId).isFilter('space_id', null)
        : query.eq('space_id', spaceId);
    final updated = await query.select().single();

    return SavingsGoalModel.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<void> deleteGoal(String goalId, {String? spaceId}) async {
    final userId = await _resolveUserId();
    var query = _supabase.from('savings_goals').delete().eq('id', goalId);
    query = spaceId == null
        ? query.eq('user_id', userId).isFilter('space_id', null)
        : query.eq('space_id', spaceId);
    await query;
  }

  Future<SavingsGoalModel> topUp(
    String goalId,
    double amount,
    String accountId,
    String? note,
    String? spaceId,
  ) async {
    final userId = await _resolveUserId();
    if (amount <= 0) {
      throw Exception('Nominal top up harus lebih dari 0');
    }

    final response = await _supabase.rpc(
      'top_up_savings_goal',
      params: {
        'p_goal_id': goalId,
        'p_user_id': userId,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_note': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'p_space_id': spaceId,
      },
    );

    return SavingsGoalModel.fromJson(Map<String, dynamic>.from(response));
  }

  Future<SavingsGoalModel> withdraw(
    String goalId,
    double amount,
    String accountId,
    String? note,
    String? spaceId,
  ) async {
    final userId = await _resolveUserId();
    if (amount <= 0) {
      throw Exception('Nominal tarik dana harus lebih dari 0');
    }

    final response = await _supabase.rpc(
      'withdraw_savings_goal',
      params: {
        'p_goal_id': goalId,
        'p_user_id': userId,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_note': (note ?? '').trim().isEmpty ? null : note!.trim(),
        'p_space_id': spaceId,
      },
    );

    return SavingsGoalModel.fromJson(Map<String, dynamic>.from(response));
  }

  void _validateGoal(SavingsGoalModel goal) {
    if (goal.name.trim().isEmpty) {
      throw Exception('Nama goal wajib diisi');
    }
    if (goal.name.trim().length > 30) {
      throw Exception('Nama goal maksimal 30 karakter');
    }
    if (goal.targetAmount <= 0) {
      throw Exception('Target amount harus lebih dari 0');
    }

    final now = DateTime.now();
    final minDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 30));
    final selected = DateTime(
      goal.targetDate.year,
      goal.targetDate.month,
      goal.targetDate.day,
    );

    if (selected.isBefore(minDate)) {
      throw Exception('Target date minimal 1 bulan dari sekarang');
    }
  }

  static String _dateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository(offlineStore: OfflineStore());
});

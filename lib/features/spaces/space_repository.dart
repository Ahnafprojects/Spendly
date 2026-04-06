import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/services/offline_store.dart';
import 'space_model.dart';

class SpaceRepository {
  final SupabaseClient _supabase;
  final OfflineStore _offlineStore;

  SpaceRepository({
    SupabaseClient? supabase,
    required OfflineStore offlineStore,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _offlineStore = offlineStore;

  Future<String> _requireAuthUserId() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId == null || authId.isEmpty) {
      throw Exception('Sesi login tidak valid. Silakan login ulang.');
    }
    await _offlineStore.saveLastUserId(authId);
    return authId;
  }

  String? get currentUserEmail => _supabase.auth.currentUser?.email;

  Future<SpaceModel> createSpace(String name) async {
    await _requireAuthUserId();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Nama shared space wajib diisi');
    }

    final row = await _supabase.rpc(
      'create_space_with_owner',
      params: {'p_name': cleanName},
    );
    return SpaceModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateSpace({
    required String spaceId,
    required String name,
  }) async {
    await _requireAuthUserId();
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('Nama shared space wajib diisi');
    }
    await _supabase
        .from('spaces')
        .update({'name': cleanName})
        .eq('id', spaceId);
  }

  Future<void> deleteSpace(String spaceId) async {
    await _requireAuthUserId();
    await _supabase.from('spaces').delete().eq('id', spaceId);
  }

  Future<List<SpaceModel>> fetchMySpaces() async {
    final userId = await _requireAuthUserId();
    final owned = await _supabase
        .from('spaces')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: true);

    final memberRows = await _supabase
        .from('space_members')
        .select('space_id')
        .eq('user_id', userId);
    final memberIds = (memberRows as List)
        .cast<Map<String, dynamic>>()
        .map((e) => (e['space_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    final ownedList = (owned as List)
        .cast<Map<String, dynamic>>()
        .map(SpaceModel.fromJson)
        .toList();
    final ownedIds = ownedList.map((e) => e.id).toSet();
    final onlyMemberIds = memberIds.difference(ownedIds);

    if (onlyMemberIds.isEmpty) return ownedList;

    final memberSpaces = await _supabase
        .from('spaces')
        .select()
        .inFilter('id', onlyMemberIds.toList())
        .order('created_at', ascending: true);
    final list = (memberSpaces as List)
        .cast<Map<String, dynamic>>()
        .map(SpaceModel.fromJson)
        .toList();

    return [...ownedList, ...list];
  }

  Future<String?> resolveUserIdByEmail(String email) async {
    final response = await _supabase.rpc(
      'find_user_id_by_email',
      params: {'p_email': email.trim().toLowerCase()},
    );
    final raw = response?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  Future<InvitationModel> inviteMember(
    String email,
    String spaceId, {
    String? invitedUserId,
  }) async {
    final userId = await _requireAuthUserId();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) throw Exception('Email wajib diisi');

    final row = await _supabase
        .from('invitations')
        .insert({
          'space_id': spaceId,
          'invited_by': userId,
          'invited_email': cleanEmail,
          'invited_user_id': invitedUserId,
          'status': 'pending',
        })
        .select()
        .single();
    return InvitationModel.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _supabase.rpc(
      'accept_space_invitation',
      params: {'p_invitation_id': invitationId},
    );
  }

  Future<void> declineInvitation(String invitationId) async {
    await _supabase
        .from('invitations')
        .update({'status': 'declined'})
        .eq('id', invitationId)
        .eq('status', 'pending');
  }

  Future<List<InvitationModel>> fetchPendingInvitationsForSpace(
    String spaceId,
  ) async {
    final rows = await _supabase
        .from('invitations')
        .select('*, spaces(name)')
        .eq('space_id', spaceId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InvitationModel.fromJson)
        .toList();
  }

  Future<List<InvitationModel>> fetchMyInboxInvitations() async {
    final email = currentUserEmail?.toLowerCase();
    if (email == null || email.isEmpty) return const [];

    final uid = await _requireAuthUserId();
    final rows = await _supabase
        .from('invitations')
        .select('*, spaces(name)')
        .or('invited_user_id.eq.$uid,invited_email.eq.$email')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(InvitationModel.fromJson)
        .toList();
  }

  Future<List<SpaceMemberModel>> fetchMembers(String spaceId) async {
    final rows = await _supabase
        .from('space_members')
        .select('*, profiles(full_name)')
        .eq('space_id', spaceId)
        .order('joined_at', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(SpaceMemberModel.fromJson)
        .toList();
  }

  Future<void> updateMemberRole(String memberId, SpaceRole role) async {
    await _supabase
        .from('space_members')
        .update({'role': spaceRoleValue(role)})
        .eq('id', memberId);
  }

  Future<void> removeMember(String memberId) async {
    await _supabase.from('space_members').delete().eq('id', memberId);
  }

  Future<List<ActivityLogModel>> fetchActivityLog(String spaceId) async {
    final rows = await _supabase
        .from('activity_log')
        .select()
        .eq('space_id', spaceId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ActivityLogModel.fromJson)
        .toList();
  }

  Future<void> addActivityLog({
    required String spaceId,
    required String action,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = await _requireAuthUserId();
    await _supabase.from('activity_log').insert({
      'space_id': spaceId,
      'user_id': userId,
      'action': action,
      'description': description,
      'metadata': metadata,
    });
  }
}

final spaceRepositoryProvider = Provider<SpaceRepository>((ref) {
  return SpaceRepository(offlineStore: OfflineStore());
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_notifier.dart';
import 'space_model.dart';
import 'space_repository.dart';

const _activeSpaceKey = 'active_space_id_v1';

class ActiveSpaceNotifier extends StateNotifier<String?> {
  ActiveSpaceNotifier(this.ref) : super(null) {
    _hydrate();
  }

  final Ref ref;

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_activeSpaceKey);
  }

  Future<void> switchSpace(String? spaceId) async {
    state = spaceId;
    final prefs = await SharedPreferences.getInstance();
    if (spaceId == null || spaceId.isEmpty) {
      await prefs.remove(_activeSpaceKey);
    } else {
      await prefs.setString(_activeSpaceKey, spaceId);
    }

    ref.read(activeAccountIdProvider.notifier).state = null;
  }
}

final activeSpaceIdProvider =
    StateNotifierProvider<ActiveSpaceNotifier, String?>((ref) {
      return ActiveSpaceNotifier(ref);
    });

final spaceListProvider = FutureProvider<List<SpaceModel>>((ref) async {
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.fetchMySpaces();
});

final currentSpaceProvider = Provider<SpaceModel?>((ref) {
  final activeSpaceId = ref.watch(activeSpaceIdProvider);
  final spaces = ref.watch(spaceListProvider).valueOrNull ?? const [];
  if (activeSpaceId == null) return null;
  for (final space in spaces) {
    if (space.id == activeSpaceId) return space;
  }
  return null;
});

final spaceMembersProvider = FutureProvider<List<SpaceMemberModel>>((
  ref,
) async {
  final activeSpaceId = ref.watch(activeSpaceIdProvider);
  if (activeSpaceId == null) return const [];
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.fetchMembers(activeSpaceId);
});

final spacePendingInvitationsProvider = FutureProvider<List<InvitationModel>>((
  ref,
) async {
  final activeSpaceId = ref.watch(activeSpaceIdProvider);
  if (activeSpaceId == null) return const [];
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.fetchPendingInvitationsForSpace(activeSpaceId);
});

final spaceInboxInvitationsProvider = FutureProvider<List<InvitationModel>>((
  ref,
) async {
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.fetchMyInboxInvitations();
});

final spaceActivityProvider = FutureProvider<List<ActivityLogModel>>((
  ref,
) async {
  final activeSpaceId = ref.watch(activeSpaceIdProvider);
  if (activeSpaceId == null) return const [];
  final repo = ref.watch(spaceRepositoryProvider);
  return repo.fetchActivityLog(activeSpaceId);
});

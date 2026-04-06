import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/spaces/space_model.dart';
import '../../features/spaces/space_notifier.dart';
import '../../features/spaces/space_repository.dart';
import '../../features/spaces/widgets/invitation_dialog.dart';

class InvitationService {
  Future<List<InvitationModel>> checkPendingInvitations(WidgetRef ref) async {
    final repo = ref.read(spaceRepositoryProvider);
    return repo.fetchMyInboxInvitations();
  }

  Future<void> showInvitationDialog(
    BuildContext context,
    WidgetRef ref,
    InvitationModel invitation,
  ) async {
    final repo = ref.read(spaceRepositoryProvider);
    await showDialog<void>(
      context: context,
      builder: (_) => InvitationDialog(
        invitation: invitation,
        repository: repo,
        onCompleted: () {
          ref.invalidate(spaceInboxInvitationsProvider);
          ref.invalidate(spaceListProvider);
        },
      ),
    );
  }

  Future<void> promptPendingInvitations(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final list = await checkPendingInvitations(ref);
      if (list.isEmpty || !context.mounted) return;
      await showInvitationDialog(context, ref, list.first);
    } on SocketException catch (e) {
      debugPrint('InvitationService: network error: $e');
    } catch (e) {
      debugPrint('InvitationService: failed to fetch invitations: $e');
    }
  }
}

final invitationServiceProvider = Provider<InvitationService>((ref) {
  return InvitationService();
});

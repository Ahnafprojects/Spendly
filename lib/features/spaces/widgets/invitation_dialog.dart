import 'package:flutter/material.dart';

import '../../../shared/widgets/app_notice.dart';
import '../space_model.dart';
import '../space_repository.dart';

class InvitationDialog extends StatefulWidget {
  final InvitationModel invitation;
  final SpaceRepository repository;
  final VoidCallback? onCompleted;

  const InvitationDialog({
    super.key,
    required this.invitation,
    required this.repository,
    this.onCompleted,
  });

  @override
  State<InvitationDialog> createState() => _InvitationDialogState();
}

class _InvitationDialogState extends State<InvitationDialog> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Undangan Shared Space'),
      content: Text(
        '${widget.invitation.inviterName ?? 'Seseorang'} mengundang kamu ke "${widget.invitation.spaceName ?? 'Shared Space'}".',
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _loading = true);
                  try {
                    await widget.repository.declineInvitation(
                      widget.invitation.id,
                    );
                    if (!mounted) return;
                    widget.onCompleted?.call();
                    navigator.pop(false);
                    AppNotice.info(messenger.context, 'Undangan ditolak');
                  } catch (e) {
                    if (!mounted) return;
                    AppNotice.error(
                      messenger.context,
                      'Gagal menolak undangan: $e',
                    );
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          child: const Text('Decline'),
        ),
        FilledButton(
          onPressed: _loading
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _loading = true);
                  try {
                    await widget.repository.acceptInvitation(
                      widget.invitation.id,
                    );
                    if (!mounted) return;
                    widget.onCompleted?.call();
                    navigator.pop(true);
                    AppNotice.success(
                      messenger.context,
                      'Berhasil bergabung ke shared space',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    AppNotice.error(
                      messenger.context,
                      'Gagal accept undangan: $e',
                    );
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Accept'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/app_text.dart';
import '../../../shared/widgets/app_notice.dart';
import '../space_notifier.dart';
import '../space_repository.dart';
import '../widgets/invitation_dialog.dart';

class InviteScreen extends ConsumerStatefulWidget {
  final String? fixedSpaceId;
  final bool inboxMode;

  const InviteScreen({super.key, this.fixedSpaceId, this.inboxMode = false});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  Widget build(BuildContext context) {
    final activeSpaceId = ref.watch(activeSpaceIdProvider);
    final spaces = ref.watch(spaceListProvider).valueOrNull ?? const [];
    final uniqueSpaces = <String, dynamic>{};
    for (final s in spaces) {
      uniqueSpaces[s.id] = s;
    }
    final normalizedSpaces = uniqueSpaces.values.toList();
    final selectedSpaceId = widget.fixedSpaceId != null
        ? (normalizedSpaces.any((s) => s.id == widget.fixedSpaceId)
              ? widget.fixedSpaceId
              : null)
        : (normalizedSpaces.any((s) => s.id == activeSpaceId)
              ? activeSpaceId
              : null);
    final inbox = ref.watch(spaceInboxInvitationsProvider);
    final repo = ref.watch(spaceRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.inboxMode
              ? _t('Inbox Undangan', 'Invitation Inbox')
              : _t('Invite Member', 'Invite Member'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: widget.inboxMode
            ? inbox.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        _t(
                          'Tidak ada undangan pending',
                          'No pending invitations',
                        ),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF5B6275),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final invite = items[index];
                      return ListTile(
                        tileColor: isDark
                            ? const Color(0xFF151A2A)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFDDE5F7),
                          ),
                        ),
                        title: Text(invite.spaceName ?? 'Shared Space'),
                        subtitle: Text(
                          '${_t('Diundang oleh', 'Invited by')} ${invite.inviterName ?? invite.invitedBy}',
                        ),
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => InvitationDialog(
                            invitation: invite,
                            repository: repo,
                            onCompleted: () {
                              ref.invalidate(spaceInboxInvitationsProvider);
                              ref.invalidate(spaceListProvider);
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedSpaceId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _t('Shared Space', 'Shared Space'),
                    ),
                    items: normalizedSpaces
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(
                              s.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: widget.fixedSpaceId != null
                        ? null
                        : (value) {
                            ref
                                .read(activeSpaceIdProvider.notifier)
                                .switchSpace(value);
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: _t('Email member', 'Member email'),
                      hintText: 'user@email.com',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _submitting || selectedSpaceId == null
                          ? null
                          : () => _submitInvite(selectedSpaceId),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_t('Kirim Undangan', 'Send Invitation')),
                    ),
                  ),
                  if (selectedSpaceId == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _t(
                        'Pilih shared space dulu sebelum invite member.',
                        'Choose a shared space before inviting member.',
                      ),
                      style: TextStyle(
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF5B6275),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _submitInvite(String spaceId) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppNotice.warning(context, _t('Email wajib diisi', 'Email is required'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final repo = ref.read(spaceRepositoryProvider);
      final foundUserId = await repo.resolveUserIdByEmail(email);
      if (!mounted) return;

      if (foundUserId == null) {
        final ask = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(_t('User belum terdaftar', 'User not registered')),
            content: Text(
              _t(
                'User belum terdaftar. Tetap kirim link undangan?',
                'User is not registered. Send invitation link anyway?',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(_t('Batal', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_t('Kirim', 'Send')),
              ),
            ],
          ),
        );
        if (ask != true) return;
      }

      await repo.inviteMember(email, spaceId, invitedUserId: foundUserId);
      ref.invalidate(spacePendingInvitationsProvider);
      ref.invalidate(spaceInboxInvitationsProvider);
      if (!mounted) return;
      AppNotice.success(context, _t('Undangan terkirim', 'Invitation sent'));
      _emailController.clear();
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal kirim undangan', 'Failed to send invitation')}: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_text.dart';
import '../../../shared/widgets/app_notice.dart';
import '../space_model.dart';
import '../space_notifier.dart';
import '../space_repository.dart';
import '../widgets/space_switcher_widget.dart';
import 'invite_screen.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  String _t(String id, String en) => AppText.t(id: id, en: en);

  @override
  Widget build(BuildContext context) {
    final activeSpace = ref.watch(currentSpaceProvider);
    final membersState = ref.watch(spaceMembersProvider);
    final pendingState = ref.watch(spacePendingInvitationsProvider);
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeSpace == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_t('Shared Members', 'Shared Members'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151A2A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFDDE5F7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Pilih Shared Space', 'Choose Shared Space'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SpaceSwitcherWidget(),
                  const SizedBox(height: 12),
                  Text(
                    _t(
                      'Belum ada space aktif. Pilih dari dropdown di atas, atau buat space baru.',
                      'No active space yet. Pick one from dropdown above, or create a new space.',
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF5B6275),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _createSpace,
                    icon: const Icon(Icons.add_business_rounded),
                    label: Text(_t('Buat Shared Space', 'Create Shared Space')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_t('Shared Members', 'Shared Members'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_members_invite',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InviteScreen(fixedSpaceId: activeSpace.id),
            ),
          );
          ref.invalidate(spacePendingInvitationsProvider);
          ref.invalidate(spaceMembersProvider);
        },
        icon: const Icon(Icons.person_add_alt_rounded),
        label: Text(_t('Invite Member', 'Invite Member')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          membersState.when(
            data: (members) {
              final activeCount = members.length;
              final myMember = members.firstWhere(
                (m) => m.userId == currentUserId,
                orElse: () => members.firstWhere(
                  (m) => m.role == SpaceRole.owner,
                  orElse: () => members.first,
                ),
              );
              final canManage =
                  myMember.role == SpaceRole.owner ||
                  myMember.role == SpaceRole.admin;
              final canManageSpace = myMember.role == SpaceRole.owner;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151A2A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFDDE5F7),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.groups_rounded),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeSpace.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '$activeCount ${_t('anggota aktif', 'active members')}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF5B6275),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canManageSpace)
                              IconButton(
                                onPressed: () => _showSpaceActions(
                                  activeSpace,
                                  canDelete: true,
                                ),
                                icon: const Icon(Icons.more_vert_rounded),
                                tooltip: _t('Kelola Space', 'Manage Space'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const SpaceSwitcherWidget(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _t('Members', 'Members'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...members.map((member) {
                    final roleColor = spaceRoleColor(member.role);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
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
                      leading: CircleAvatar(
                        backgroundColor: roleColor.withValues(alpha: 0.18),
                        child: Text(
                          ((member.displayName ?? member.email ?? '?').isEmpty
                                  ? '?'
                                  : (member.displayName ?? member.email ?? '?')
                                        .substring(0, 1))
                              .toUpperCase(),
                          style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        member.displayName ?? member.email ?? member.userId,
                      ),
                      subtitle: Text(
                        '${member.email ?? '-'} • ${_t('Active', 'Active')}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          spaceRoleLabel(member.role),
                          style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      onTap: canManage
                          ? () => _showManageMember(member, myMember.role)
                          : null,
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
          const SizedBox(height: 16),
          Text(
            _t('Pending Invitations', 'Pending Invitations'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          pendingState.when(
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  _t('Tidak ada undangan pending.', 'No pending invitations.'),
                );
              }
              return Column(
                children: items.map((inv) {
                  return ListTile(
                    tileColor: isDark ? const Color(0xFF151A2A) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFDDE5F7),
                      ),
                    ),
                    title: Text(inv.invitedEmail),
                    subtitle: Text(_t('Pending', 'Pending')),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSpace() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Buat Shared Space', 'Create Shared Space')),
        content: TextField(
          controller: controller,
          maxLength: 50,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('Contoh: Keluarga', 'Example: Family'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_t('Buat', 'Create')),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    try {
      final repo = ref.read(spaceRepositoryProvider);
      final created = await repo.createSpace(name.trim());
      await ref.read(activeSpaceIdProvider.notifier).switchSpace(created.id);
      ref.invalidate(spaceListProvider);
      ref.invalidate(spaceMembersProvider);
      ref.invalidate(spacePendingInvitationsProvider);
      if (!mounted) return;
      AppNotice.success(
        context,
        _t('Shared space berhasil dibuat', 'Shared space created'),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(context, '${_t('Gagal buat space', 'Create failed')}: $e');
    }
  }

  Future<void> _showManageMember(
    SpaceMemberModel member,
    SpaceRole myRole,
  ) async {
    final repo = ref.read(spaceRepositoryProvider);
    final isOwner = myRole == SpaceRole.owner;
    final options = <(String label, SpaceRole role)>[];
    if (isOwner) {
      options.add(('Owner', SpaceRole.owner));
      options.add(('Admin', SpaceRole.admin));
      options.add(('Member', SpaceRole.member));
    } else {
      options.add(('Admin', SpaceRole.admin));
      options.add(('Member', SpaceRole.member));
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...options.map((option) {
                return ListTile(
                  title: Text(
                    '${_t('Set role', 'Set role')}: ${option.$1}',
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await repo.updateMemberRole(member.id, option.$2);
                      ref.invalidate(spaceMembersProvider);
                      if (!mounted) return;
                      AppNotice.success(
                        context,
                        _t('Role berhasil diubah', 'Role updated'),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      AppNotice.error(context, 'Error: $e');
                    }
                  },
                );
              }),
              ListTile(
                textColor: Colors.red,
                iconColor: Colors.red,
                leading: const Icon(Icons.person_remove_alt_1_rounded),
                title: Text(_t('Hapus member', 'Remove member')),
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await repo.removeMember(member.id);
                    ref.invalidate(spaceMembersProvider);
                    if (!mounted) return;
                    AppNotice.info(
                      context,
                      _t('Member dihapus', 'Member removed'),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    AppNotice.error(context, 'Error: $e');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSpaceActions(
    SpaceModel space, {
    required bool canDelete,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(_t('Edit Nama Space', 'Edit Space Name')),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: Text(
                  _t('Hapus Space', 'Delete Space'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'edit') {
      await _editSpace(space);
      return;
    }
    if (action == 'delete') {
      await _deleteSpace(space);
    }
  }

  Future<void> _editSpace(SpaceModel space) async {
    final controller = TextEditingController(text: space.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Edit Nama Space', 'Edit Space Name')),
        content: TextField(
          controller: controller,
          maxLength: 50,
          autofocus: true,
          decoration: InputDecoration(
            hintText: _t('Masukkan nama space', 'Enter space name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_t('Simpan', 'Save')),
          ),
        ],
      ),
    );

    if (!mounted || name == null || name.trim().isEmpty) return;
    if (name.trim() == space.name.trim()) return;

    try {
      await ref
          .read(spaceRepositoryProvider)
          .updateSpace(spaceId: space.id, name: name.trim());
      ref.invalidate(spaceListProvider);
      if (!mounted) return;
      AppNotice.success(
        context,
        _t('Nama space diperbarui', 'Space name updated'),
      );
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal update space', 'Failed to update space')}: $e',
      );
    }
  }

  Future<void> _deleteSpace(SpaceModel space) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Hapus Space?', 'Delete Space?')),
        content: Text(
          _t(
            'Semua data bersama di space ini akan ikut terhapus. Lanjutkan?',
            'All shared data in this space will also be deleted. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_t('Hapus', 'Delete')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await ref.read(spaceRepositoryProvider).deleteSpace(space.id);
      await ref.read(activeSpaceIdProvider.notifier).switchSpace(null);
      ref.invalidate(spaceListProvider);
      ref.invalidate(spaceMembersProvider);
      ref.invalidate(spacePendingInvitationsProvider);
      ref.invalidate(spaceInboxInvitationsProvider);
      if (!mounted) return;
      AppNotice.info(context, _t('Space dihapus', 'Space deleted'));
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(
        context,
        '${_t('Gagal hapus space', 'Failed to delete space')}: $e',
      );
    }
  }
}

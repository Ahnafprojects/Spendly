import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/app_text.dart';
import '../space_notifier.dart';

class SpaceSwitcherWidget extends ConsumerWidget {
  const SpaceSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesState = ref.watch(spaceListProvider);
    final activeSpaceId = ref.watch(activeSpaceIdProvider);
    final inboxInvites =
        ref.watch(spaceInboxInvitationsProvider).valueOrNull ?? const [];
    final hasPendingInvite = inboxInvites.isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseText = isDark ? Colors.white : const Color(0xFF1A1E2A);
    final muted = isDark ? Colors.white60 : const Color(0xFF5B6275);

    return spacesState.when(
      data: (spaces) {
        final uniqueSpaces = <String, dynamic>{};
        for (final s in spaces) {
          uniqueSpaces[s.id] = s;
        }
        final normalizedSpaces = uniqueSpaces.values.toList();
        final safeValue = normalizedSpaces.any((s) => s.id == activeSpaceId)
            ? activeSpaceId
            : null;

        final items = [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(AppText.t(id: 'Personal Space', en: 'Personal Space')),
          ),
          ...normalizedSpaces.map(
            (space) => DropdownMenuItem<String?>(
              value: space.id,
              child: Text(space.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        ];

        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A2033)
                      : const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: safeValue,
                    isExpanded: true,
                    iconEnabledColor: muted,
                    dropdownColor: isDark
                        ? const Color(0xFF1A2033)
                        : Colors.white,
                    style: TextStyle(
                      color: baseText,
                      fontWeight: FontWeight.w700,
                    ),
                    items: items,
                    onChanged: (value) => ref
                        .read(activeSpaceIdProvider.notifier)
                        .switchSpace(value),
                  ),
                ),
              ),
            ),
            if (hasPendingInvite) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5A6E),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        );
      },
      loading: () => Text(
        AppText.t(id: 'Memuat space...', en: 'Loading space...'),
        style: TextStyle(color: muted, fontSize: 12),
      ),
      error: (_, __) => Text(
        AppText.t(id: 'Space error', en: 'Space error'),
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}

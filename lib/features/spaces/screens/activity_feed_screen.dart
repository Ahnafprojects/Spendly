import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/language_settings.dart';
import '../space_model.dart';
import '../space_notifier.dart';
import '../space_repository.dart';

class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  RealtimeChannel? _channel;
  List<ActivityLogModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boot();
    });
  }

  Future<void> _boot() async {
    final activeSpaceId = ref.read(activeSpaceIdProvider);
    if (activeSpaceId == null || activeSpaceId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final repo = ref.read(spaceRepositoryProvider);
    final fetched = await repo.fetchActivityLog(activeSpaceId);
    if (mounted) {
      setState(() {
        _items = fetched;
        _loading = false;
      });
    }

    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('space:$activeSpaceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activity_log',
          callback: (payload) {
            final row = payload.newRecord;
            final mapped = ActivityLogModel.fromJson(
              Map<String, dynamic>.from(row),
            );
            if (mapped.spaceId != activeSpaceId) return;
            if (!mounted) return;
            setState(() {
              _items = [mapped, ..._items];
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSpace = ref.watch(currentSpaceProvider);
    final locale = LanguageSettings.current.locale.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Feed')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : currentSpace == null
          ? const Center(child: Text('Pilih shared space dulu'))
          : _items.isEmpty
          ? const Center(child: Text('Belum ada aktivitas'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = _items[i];
                return ListTile(
                  tileColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF151A2A)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : const Color(0xFFDDE5F7),
                    ),
                  ),
                  leading: CircleAvatar(
                    child: Text(
                      ((item.userName ?? item.userEmail ?? 'U').isEmpty
                              ? 'U'
                              : (item.userName ?? item.userEmail ?? 'U')
                                    .substring(0, 1))
                          .toUpperCase(),
                    ),
                  ),
                  title: Text(item.description),
                  subtitle: Text(
                    DateFormat(
                      'dd MMM yyyy HH:mm',
                      locale,
                    ).format(item.createdAt),
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/spaces/space_notifier.dart';
import '../../features/spaces/space_repository.dart';

class ActivityLogService {
  ActivityLogService(this._ref);

  final Ref _ref;

  Future<void> log({
    required String action,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final spaceId = _ref.read(activeSpaceIdProvider);
    if (spaceId == null || spaceId.isEmpty) return;
    try {
      final repo = _ref.read(spaceRepositoryProvider);
      await repo.addActivityLog(
        spaceId: spaceId,
        action: action,
        description: description,
        metadata: metadata,
      );
      _ref.invalidate(spaceActivityProvider);
    } catch (_) {
      // Keep the primary feature flow resilient when activity log fails.
    }
  }
}

final activityLogServiceProvider = Provider<ActivityLogService>((ref) {
  return ActivityLogService(ref);
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_notifier.dart';
import '../spaces/space_notifier.dart';
import 'insights_model.dart';
import 'insights_service.dart';

class InsightsNotifier extends AsyncNotifier<InsightsBundle> {
  late InsightsService _service;

  @override
  FutureOr<InsightsBundle> build() async {
    _service = ref.watch(insightsServiceProvider);
    ref.watch(activeAccountIdProvider);
    ref.watch(activeSpaceIdProvider);
    return _service.loadInsights(
      accountId: ref.read(activeAccountIdProvider),
      spaceId: ref.read(activeSpaceIdProvider),
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _service.loadInsights(
        accountId: ref.read(activeAccountIdProvider),
        spaceId: ref.read(activeSpaceIdProvider),
        forceRefresh: true,
      ),
    );
  }
}

final insightsNotifierProvider =
    AsyncNotifierProvider<InsightsNotifier, InsightsBundle>(
      () => InsightsNotifier(),
    );

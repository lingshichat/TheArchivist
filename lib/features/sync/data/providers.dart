import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/providers.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

export 'sync_models.dart';
export 'sync_queue.dart';
export 'sync_status.dart';

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  return SyncQueueRepository(
    database: ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  return SyncStatusRepository(database: ref.watch(appDatabaseProvider));
});

final syncStatusProvider =
    StateNotifierProvider<SyncStatusController, SyncStatusState>((ref) {
      return SyncStatusController(
        statusRepository: ref.watch(syncStatusRepositoryProvider),
        queueRepository: ref.watch(syncQueueRepositoryProvider),
      );
    });

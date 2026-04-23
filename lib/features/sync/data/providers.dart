import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/providers.dart';
import 'sync_codec.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';
import 'sync_status.dart';

export 'sync_codec.dart';
export 'sync_engine.dart';
export 'sync_exception.dart';
export 'sync_merge_policy.dart';
export 'sync_models.dart';
export 'sync_queue.dart';
export 'sync_status.dart';
export 'sync_storage_adapter.dart';
export 'sync_summary.dart';

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  return SyncQueueRepository(
    database: ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  return SyncStatusRepository(database: ref.watch(appDatabaseProvider));
});

final syncCodecProvider = Provider<SyncCodec>((ref) {
  return SyncCodec(
    database: ref.watch(appDatabaseProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    userEntryRepository: ref.watch(userEntryRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    shelfRepository: ref.watch(shelfRepositoryProvider),
    activityLogRepository: ref.watch(activityLogRepositoryProvider),
  );
});

final syncStatusProvider =
    StateNotifierProvider<SyncStatusController, SyncStatusState>((ref) {
      return SyncStatusController(
        statusRepository: ref.watch(syncStatusRepositoryProvider),
        queueRepository: ref.watch(syncQueueRepositoryProvider),
      );
    });

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    queueRepository: ref.watch(syncQueueRepositoryProvider),
    statusController: ref.read(syncStatusProvider.notifier),
    codec: ref.watch(syncCodecProvider),
  );
});

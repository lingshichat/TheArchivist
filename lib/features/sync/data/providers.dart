import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/providers.dart';
import '../../../shared/network/s3_api_client.dart';
import '../../../shared/network/webdav_api_client.dart';
import 's3_storage_adapter.dart';
import 'sync_connection_test.dart';
import 'sync_codec.dart';
import 'sync_conflict.dart';
import 'sync_engine.dart';
import 'sync_operations_service.dart';
import 'sync_queue.dart';
import 'snapshot_service.dart';
import 'sync_status.dart';
import 'sync_target_config.dart';
import 'webdav_storage_adapter.dart';
import 'sync_target_store.dart';

export 's3_storage_adapter.dart';
export 'sync_connection_test.dart';
export 'sync_codec.dart';
export 'sync_conflict.dart';
export 'sync_engine.dart';
export 'sync_exception.dart';
export 'sync_merge_policy.dart';
export 'sync_models.dart';
export 'sync_operations_service.dart';
export 'sync_queue.dart';
export 'snapshot_service.dart';
export 'sync_status.dart';
export 'sync_storage_adapter.dart';
export 'sync_summary.dart';
export 'sync_target_config.dart';
export 'sync_target_store.dart';
export 'webdav_storage_adapter.dart';

final syncQueueRepositoryProvider = Provider<SyncQueueRepository>((ref) {
  return SyncQueueRepository(
    database: ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  return SyncStatusRepository(database: ref.watch(appDatabaseProvider));
});

final syncConflictRepositoryProvider = Provider<SyncConflictRepository>((ref) {
  return SyncConflictRepository(database: ref.watch(appDatabaseProvider));
});

final syncTargetStoreProvider = Provider<SyncTargetStore>((ref) {
  return SecureSyncTargetStore();
});

final syncTargetConfigProvider = FutureProvider<SyncTargetConfig>((ref) async {
  final store = ref.watch(syncTargetStoreProvider);
  return store.read();
});

final syncConnectionTestServiceProvider = Provider<SyncConnectionTestService>((
  ref,
) {
  return SyncConnectionTestService(
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
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
    conflictRepository: ref.watch(syncConflictRepositoryProvider),
    statusController: ref.read(syncStatusProvider.notifier),
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

final syncOperationsServiceProvider = Provider<SyncOperationsService>((ref) {
  return SyncOperationsService(
    engine: ref.watch(syncEngineProvider),
    statusController: ref.read(syncStatusProvider.notifier),
    queueRepository: ref.watch(syncQueueRepositoryProvider),
  );
});

final syncPendingItemsProvider = FutureProvider<List<SyncQueueItem>>((ref) {
  final queueRepo = ref.watch(syncQueueRepositoryProvider);
  return queueRepo.listPending();
});

final snapshotServiceProvider = Provider<SnapshotService>((ref) {
  return SnapshotService(
    database: ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
    codec: ref.watch(syncCodecProvider),
  );
});

final webDavApiClientProvider =
    Provider.family<WebDavApiClient, WebDavStorageAdapterConfig>((ref, config) {
      return WebDavApiClient(
        baseUri: config.baseUri,
        authProvider: () async {
          return WebDavAuth(
            username: config.username,
            password: config.password,
          );
        },
      );
    });

final webDavStorageAdapterProvider =
    Provider.family<WebDavStorageAdapter, WebDavStorageAdapterConfig>((
      ref,
      config,
    ) {
      return WebDavStorageAdapter(
        client: ref.watch(webDavApiClientProvider(config)),
        rootPath: config.rootPath,
      );
    });

final s3ApiClientProvider =
    Provider.family<S3ApiClient, S3StorageAdapterConfig>((ref, config) {
      return S3ApiClient(
        requestConfig: S3RequestConfig(
          endpoint: config.endpoint,
          region: config.region,
          bucket: config.bucket,
          rootPrefix: config.rootPrefix,
          addressingStyle: config.addressingStyle,
        ),
        credentialsProvider: () async {
          return S3Credentials(
            accessKey: config.accessKey,
            secretKey: config.secretKey,
            sessionToken: config.sessionToken,
          );
        },
      );
    });

final s3StorageAdapterProvider =
    Provider.family<S3StorageAdapter, S3StorageAdapterConfig>((ref, config) {
      return S3StorageAdapter(
        client: ref.watch(s3ApiClientProvider(config)),
        rootPrefix: config.rootPrefix,
      );
    });

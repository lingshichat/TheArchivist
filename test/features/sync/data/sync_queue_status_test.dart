import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/sync/data/sync_models.dart';
import 'package:record_anywhere/features/sync/data/providers.dart';
import 'package:record_anywhere/features/sync/data/sync_queue.dart';
import 'package:record_anywhere/features/sync/data/sync_status.dart';
import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/device_identity.dart';
import 'package:record_anywhere/shared/data/providers.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/user_entry_repository.dart';

void main() {
  late AppDatabase db;
  late DeviceIdentityService deviceIdentityService;
  late SyncQueueRepository syncQueueRepository;
  late SyncStatusRepository syncStatusRepository;
  late MediaRepository mediaRepository;
  late UserEntryRepository userEntryRepository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceIdentityService = DeviceIdentityService(
      store: InMemoryDeviceIdentityStore(deviceId: 'test-device-id'),
    );
    syncQueueRepository = SyncQueueRepository(
      database: db,
      deviceIdentityService: deviceIdentityService,
    );
    syncStatusRepository = SyncStatusRepository(database: db);
    mediaRepository = MediaRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    userEntryRepository = UserEntryRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueue de-duplicates unfinished queue item', () async {
    final first = await syncQueueRepository.enqueue(
      entityType: SyncEntityType.mediaItem,
      entityId: 'media-1',
      operation: SyncOperationType.upsert,
      snapshot: SyncEntityEnvelope(
        entityType: SyncEntityType.mediaItem,
        entityId: 'media-1',
        updatedAt: DateTime(2026, 4, 22, 9, 0),
        deviceId: 'test-device-id',
        payload: <String, Object?>{'title': 'A'},
      ),
    );

    final second = await syncQueueRepository.enqueue(
      entityType: SyncEntityType.mediaItem,
      entityId: 'media-1',
      operation: SyncOperationType.upsert,
      snapshot: SyncEntityEnvelope(
        entityType: SyncEntityType.mediaItem,
        entityId: 'media-1',
        updatedAt: DateTime(2026, 4, 22, 9, 5),
        deviceId: 'test-device-id',
        payload: <String, Object?>{'title': 'B'},
      ),
    );

    final pending = await syncQueueRepository.listPending();
    expect(first.id, second.id);
    expect(pending, hasLength(1));
    expect(pending.single.deviceId, 'test-device-id');
    expect(pending.single.snapshotJson, contains('"title":"B"'));
  });

  test('recordAttempt and markCompleted persist queue lifecycle', () async {
    final item = await syncQueueRepository.enqueue(
      entityType: SyncEntityType.userEntry,
      entityId: 'entry-1',
      operation: SyncOperationType.delete,
    );

    await syncQueueRepository.recordAttempt(
      queueItemId: item.id,
      retryCount: 2,
      errorSummary: 'network down',
    );
    await syncQueueRepository.markCompleted(item.id);

    final rows = await db.select(db.syncQueueEntries).get();
    expect(rows.single.retryCount, 2);
    expect(rows.single.lastAttemptedAt, isNotNull);
    expect(rows.single.completedAt, isNotNull);
    expect(rows.single.errorSummary, isNull);
  });

  test('status repository persists minimal status snapshot', () async {
    await syncStatusRepository.setStatus(
      isRunning: true,
      pendingCount: 3,
      lastErrorSummary: 'timeout',
      lastCompletedAt: DateTime(2026, 4, 22, 12, 0),
      hasConflicts: true,
    );

    final state = await syncStatusRepository.readStatus();
    expect(state.isRunning, isTrue);
    expect(state.pendingCount, 3);
    expect(state.lastErrorSummary, 'timeout');
    expect(state.lastCompletedAt, DateTime(2026, 4, 22, 12, 0));
    expect(state.hasConflicts, isTrue);
  });

  test('sync status provider reflects running success failure and conflict', () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        deviceIdentityServiceProvider.overrideWithValue(deviceIdentityService),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(syncStatusProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await controller.markRunning();
    expect(container.read(syncStatusProvider).isRunning, isTrue);

    await controller.markCompleted();
    final success = container.read(syncStatusProvider);
    expect(success.isRunning, isFalse);
    expect(success.lastCompletedAt, isNotNull);
    expect(success.lastErrorSummary, isNull);

    await controller.markRunning();
    await controller.markCompleted(errorSummary: 'timeout');
    final failure = container.read(syncStatusProvider);
    expect(failure.isRunning, isFalse);
    expect(failure.lastErrorSummary, 'timeout');

    await controller.markHasConflicts();
    expect(container.read(syncStatusProvider).hasConflicts, isTrue);
  });

  test('sync change candidate matches wp1 dirty rules', () {
    final neverSynced = SyncChangeCandidate(
      entityType: SyncEntityType.mediaItem,
      entityId: '1',
      updatedAt: DateTime(2026, 4, 22, 9, 0),
      deviceId: 'test-device-id',
      lastSyncedAt: null,
    );
    final updatedAfterSync = SyncChangeCandidate(
      entityType: SyncEntityType.mediaItem,
      entityId: '2',
      updatedAt: DateTime(2026, 4, 22, 10, 0),
      deviceId: 'test-device-id',
      lastSyncedAt: DateTime(2026, 4, 22, 9, 0),
    );
    final softDeleted = SyncChangeCandidate(
      entityType: SyncEntityType.mediaItem,
      entityId: '3',
      updatedAt: DateTime(2026, 4, 22, 8, 0),
      deletedAt: DateTime(2026, 4, 22, 11, 0),
      deviceId: 'test-device-id',
      lastSyncedAt: DateTime(2026, 4, 22, 9, 0),
    );
    final clean = SyncChangeCandidate(
      entityType: SyncEntityType.mediaItem,
      entityId: '4',
      updatedAt: DateTime(2026, 4, 22, 8, 0),
      deviceId: 'test-device-id',
      lastSyncedAt: DateTime(2026, 4, 22, 9, 0),
    );

    expect(neverSynced.needsSync, isTrue);
    expect(updatedAfterSync.needsSync, isTrue);
    expect(softDeleted.needsSync, isTrue);
    expect(clean.needsSync, isFalse);
  });

  test(
    'listChangeCandidates identifies new, updated and soft-deleted rows',
    () async {
      final newMediaId = await mediaRepository.createItem(
        mediaType: MediaType.movie,
        title: 'Never Synced',
      );

      final updatedMediaId = await mediaRepository.createItem(
        mediaType: MediaType.tv,
        title: 'Updated After Sync',
      );
      await userEntryRepository.markSynced(
        updatedMediaId,
        DateTime(2026, 4, 22, 8, 0),
      );
      await userEntryRepository.updateScore(updatedMediaId, 9);
      final updatedEntry = await db.userEntryDao.getByMediaItemId(
        updatedMediaId,
      );

      final deletedMediaId = await mediaRepository.createItem(
        mediaType: MediaType.book,
        title: 'Soft Deleted',
      );
      await mediaRepository.markSynced(
        deletedMediaId,
        DateTime(2026, 4, 22, 8, 0),
      );
      await mediaRepository.softDelete(deletedMediaId);

      final candidates = await syncQueueRepository.listChangeCandidates(
        limit: 50,
      );

      expect(
        candidates.any(
          (item) =>
              item.entityType == SyncEntityType.mediaItem &&
              item.entityId == newMediaId &&
              item.lastSyncedAt == null,
        ),
        isTrue,
      );
      expect(
        candidates.any(
          (item) =>
              item.entityType == SyncEntityType.userEntry &&
              item.entityId == updatedEntry!.id &&
              item.deletedAt == null &&
              item.lastSyncedAt == DateTime(2026, 4, 22, 8, 0),
        ),
        isTrue,
      );
      expect(
        candidates.any(
          (item) =>
              item.entityType == SyncEntityType.mediaItem &&
              item.entityId == deletedMediaId &&
              item.deletedAt != null,
        ),
        isTrue,
      );
    },
  );

  test(
    'enqueuePendingChanges writes dirty rows into queue with proper operation',
    () async {
      final upsertMediaId = await mediaRepository.createItem(
        mediaType: MediaType.game,
        title: 'Queue Me',
      );

      final deletedMediaId = await mediaRepository.createItem(
        mediaType: MediaType.book,
        title: 'Delete Me',
      );
      await mediaRepository.markSynced(
        deletedMediaId,
        DateTime(2026, 4, 22, 8, 0),
      );
      await mediaRepository.softDelete(deletedMediaId);

      final queueItems = await syncQueueRepository.enqueuePendingChanges(
        limit: 50,
      );

      expect(
        queueItems.any(
          (item) =>
              item.entityType == SyncEntityType.mediaItem &&
              item.entityId == upsertMediaId &&
              item.operation == SyncOperationType.upsert,
        ),
        isTrue,
      );
      expect(
        queueItems.any(
          (item) =>
              item.entityType == SyncEntityType.mediaItem &&
              item.entityId == deletedMediaId &&
              item.operation == SyncOperationType.delete,
        ),
        isTrue,
      );
    },
  );
}

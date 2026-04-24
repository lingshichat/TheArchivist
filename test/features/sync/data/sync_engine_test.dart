import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/sync/data/sync_codec.dart';
import 'package:record_anywhere/features/sync/data/sync_conflict.dart';
import 'package:record_anywhere/features/sync/data/sync_engine.dart';
import 'package:record_anywhere/features/sync/data/sync_exception.dart';
import 'package:record_anywhere/features/sync/data/sync_merge_policy.dart';
import 'package:record_anywhere/features/sync/data/sync_models.dart';
import 'package:record_anywhere/features/sync/data/sync_queue.dart';
import 'package:record_anywhere/features/sync/data/sync_status.dart';
import 'package:record_anywhere/features/sync/data/sync_storage_adapter.dart';
import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/device_identity.dart';
import 'package:record_anywhere/shared/data/repositories/activity_log_repository.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/progress_repository.dart';
import 'package:record_anywhere/shared/data/repositories/shelf_repository.dart';
import 'package:record_anywhere/shared/data/repositories/tag_repository.dart';
import 'package:record_anywhere/shared/data/repositories/user_entry_repository.dart';

void main() {
  late _InMemorySyncStorageAdapter adapter;
  late _SyncHarness source;
  late _SyncHarness target;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    adapter = _InMemorySyncStorageAdapter();
    source = _SyncHarness(deviceId: 'device-source');
    target = _SyncHarness(deviceId: 'device-target');
  });

  tearDown(() async {
    await source.dispose();
    await target.dispose();
  });

  test('push and pull sync core entities end to end', () async {
    final mediaItemId = await source.mediaRepository.createItem(
      mediaType: MediaType.movie,
      title: 'Interstellar',
    );
    await source.userEntryRepository.updateStatus(
      mediaItemId,
      UnifiedStatus.inProgress,
    );
    await source.userEntryRepository.updateScore(mediaItemId, 9);
    await source.progressRepository.updateProgress(
      mediaItemId,
      currentEpisode: 1,
      completionRatio: 0.2,
    );

    final tagId = await source.tagRepository.createTag(name: 'Sci-Fi');
    await source.tagRepository.attachToMedia(mediaItemId, tagId);

    final shelfId = await source.shelfRepository.createShelf(name: 'Top Picks');
    await source.shelfRepository.attachToMedia(mediaItemId, shelfId);

    await source.engine.runSync(adapter: adapter);
    final summary = await target.engine.runSync(adapter: adapter);

    final syncedMediaItem = await target.mediaRepository.getItem(mediaItemId);
    final syncedEntry = await target.userEntryRepository.getByMediaItemId(
      mediaItemId,
    );
    final syncedProgress = await target.progressRepository.getByMediaItemId(
      mediaItemId,
    );
    final syncedTags = await target.tagRepository.getByMediaItemId(mediaItemId);
    final syncedShelves = await target.shelfRepository.getByMediaItemId(
      mediaItemId,
    );

    expect(syncedMediaItem?.title, 'Interstellar');
    expect(syncedEntry?.status, UnifiedStatus.inProgress);
    expect(syncedEntry?.score, 9);
    expect(syncedProgress?.currentEpisode, 1);
    expect(syncedTags.map((item) => item.name), contains('Sci-Fi'));
    expect(syncedShelves.map((item) => item.name), contains('Top Picks'));
    expect(summary.pullAppliedCount, greaterThanOrEqualTo(6));
  });

  test('remote tombstone propagates media soft delete', () async {
    final mediaItemId = await source.mediaRepository.createItem(
      mediaType: MediaType.book,
      title: 'Deleted Later',
    );

    await source.engine.runSync(adapter: adapter);
    await target.engine.runSync(adapter: adapter);
    expect(await target.mediaRepository.getItem(mediaItemId), isNotNull);

    await source.mediaRepository.softDelete(mediaItemId);
    await source.bumpDeletedMediaTimestamp(mediaItemId);
    await source.engine.runSync(adapter: adapter);
    await target.engine.runSync(adapter: adapter);

    expect(await target.mediaRepository.getItem(mediaItemId), isNull);
  });

  test('codec keeps local newer row when remote snapshot is older', () async {
    final mediaItemId = await source.mediaRepository.createItem(
      mediaType: MediaType.tv,
      title: 'Conflict Case',
    );
    await source.userEntryRepository.updateScore(mediaItemId, 7);

    await source.engine.runSync(adapter: adapter);
    await target.engine.runSync(adapter: adapter);

    await target.userEntryRepository.updateScore(mediaItemId, 9);
    await target.bumpUserEntryTimestamp(mediaItemId);
    final sourceEntry = await source.userEntryRepository.getByMediaItemId(
      mediaItemId,
    );
    final remoteEnvelope = await source.codec.encodePendingItem(
      SyncQueueItem(
        id: 'stale-user-entry',
        entityType: SyncEntityType.userEntry,
        entityId: sourceEntry!.id,
        operation: SyncOperationType.upsert,
        createdAt: DateTime(2026, 4, 23, 9, 0),
        updatedAt: DateTime(2026, 4, 23, 9, 0),
        retryCount: 0,
        deviceId: 'device-source',
      ),
    );
    final outcome = await target.codec.applyRemoteEnvelope(remoteEnvelope);
    final localEntry = await target.userEntryRepository.getByMediaItemId(
      mediaItemId,
    );

    expect(localEntry?.score, 9);
    expect(outcome.decision, SyncMergeDecision.localWins);
  });

  test(
    'text conflicts keep copies while scalar fields follow last modified wins',
    () async {
      final mediaItemId = await source.mediaRepository.createItem(
        mediaType: MediaType.tv,
        title: 'Text Conflict Case',
      );
      await source.setUserEntryFields(
        mediaItemId,
        notes: 'base notes',
        review: 'base review',
        score: 6,
      );

      await source.engine.runSync(adapter: adapter);
      await target.engine.runSync(adapter: adapter);

      final sourceBase = await source.userEntryRepository.getByMediaItemId(
        mediaItemId,
      );
      final targetBase = await target.userEntryRepository.getByMediaItemId(
        mediaItemId,
      );
      await target.setUserEntryFields(
        mediaItemId,
        notes: 'local notes',
        review: 'local review',
        score: 9,
        updatedAt: targetBase!.updatedAt.add(const Duration(minutes: 5)),
      );
      await source.setUserEntryFields(
        mediaItemId,
        notes: 'remote notes',
        review: 'remote review',
        score: 8,
        updatedAt: sourceBase!.updatedAt.add(const Duration(minutes: 10)),
      );

      final sourceEntry = await source.userEntryRepository.getByMediaItemId(
        mediaItemId,
      );
      final remoteEnvelope = await source.codec.encodePendingItem(
        SyncQueueItem(
          id: 'remote-user-entry-conflict',
          entityType: SyncEntityType.userEntry,
          entityId: sourceEntry!.id,
          operation: SyncOperationType.upsert,
          createdAt: sourceEntry.updatedAt,
          updatedAt: sourceEntry.updatedAt,
          retryCount: 0,
          deviceId: 'device-source',
        ),
      );
      await target.codec.applyRemoteEnvelope(remoteEnvelope);

      final mergedEntry = await target.userEntryRepository.getByMediaItemId(
        mediaItemId,
      );
      final conflicts = await target.syncConflictRepository.listPending();
      final targetStatus = await target.syncStatusRepository.readStatus();

      expect(mergedEntry?.notes, 'remote notes');
      expect(mergedEntry?.review, 'remote review');
      expect(mergedEntry?.score, 8);
      expect(targetStatus.hasConflicts, isTrue);
      expect(
        conflicts.map((item) => item.fieldName),
        containsAll(['notes', 'review']),
      );
      expect(
        conflicts.singleWhere((item) => item.fieldName == 'notes').localValue,
        'local notes',
      );
      expect(
        conflicts.singleWhere((item) => item.fieldName == 'notes').remoteValue,
        'remote notes',
      );
      expect(
        conflicts.singleWhere((item) => item.fieldName == 'review').localValue,
        'local review',
      );
      expect(
        conflicts.singleWhere((item) => item.fieldName == 'review').remoteValue,
        'remote review',
      );
    },
  );

  test('failed push keeps local data and queue retry state', () async {
    adapter.failWrites = true;
    final mediaItemId = await source.mediaRepository.createItem(
      mediaType: MediaType.game,
      title: 'Offline First',
    );

    final summary = await source.engine.runSync(adapter: adapter);
    final localMediaItem = await source.mediaRepository.getItem(mediaItemId);
    final pendingItems = await source.syncQueueRepository.listPending();

    expect(localMediaItem, isNotNull);
    expect(summary.failedCount, greaterThanOrEqualTo(1));
    expect(pendingItems, isNotEmpty);
    expect(pendingItems.first.retryCount, 1);
    expect(pendingItems.first.errorSummary, isNotNull);
  });
}

class _SyncHarness {
  _SyncHarness({required String deviceId})
    : database = AppDatabase.forTesting(NativeDatabase.memory()),
      deviceIdentityService = DeviceIdentityService(
        store: InMemoryDeviceIdentityStore(deviceId: deviceId),
      ) {
    mediaRepository = MediaRepository(
      database,
      deviceIdentityService: deviceIdentityService,
    );
    userEntryRepository = UserEntryRepository(
      database,
      deviceIdentityService: deviceIdentityService,
    );
    progressRepository = ProgressRepository(
      database,
      deviceIdentityService: deviceIdentityService,
    );
    tagRepository = TagRepository(
      database,
      deviceIdentityService: deviceIdentityService,
    );
    shelfRepository = ShelfRepository(
      database,
      deviceIdentityService: deviceIdentityService,
    );
    activityLogRepository = ActivityLogRepository(
      database,
      deviceIdentityService: deviceIdentityService,
    );
    syncQueueRepository = SyncQueueRepository(
      database: database,
      deviceIdentityService: deviceIdentityService,
    );
    syncStatusRepository = SyncStatusRepository(database: database);
    syncConflictRepository = SyncConflictRepository(database: database);
    syncStatusController = SyncStatusController(
      statusRepository: syncStatusRepository,
      queueRepository: syncQueueRepository,
    );
    codec = SyncCodec(
      database: database,
      mediaRepository: mediaRepository,
      userEntryRepository: userEntryRepository,
      progressRepository: progressRepository,
      tagRepository: tagRepository,
      shelfRepository: shelfRepository,
      activityLogRepository: activityLogRepository,
      conflictRepository: syncConflictRepository,
      statusController: syncStatusController,
    );
    engine = SyncEngine(
      queueRepository: syncQueueRepository,
      statusController: syncStatusController,
      codec: codec,
    );
  }

  final AppDatabase database;
  final DeviceIdentityService deviceIdentityService;
  late final MediaRepository mediaRepository;
  late final UserEntryRepository userEntryRepository;
  late final ProgressRepository progressRepository;
  late final TagRepository tagRepository;
  late final ShelfRepository shelfRepository;
  late final ActivityLogRepository activityLogRepository;
  late final SyncQueueRepository syncQueueRepository;
  late final SyncStatusRepository syncStatusRepository;
  late final SyncConflictRepository syncConflictRepository;
  late final SyncStatusController syncStatusController;
  late final SyncCodec codec;
  late final SyncEngine engine;

  Future<void> dispose() async {
    syncStatusController.dispose();
    await database.close();
  }

  Future<void> bumpDeletedMediaTimestamp(String mediaItemId) async {
    final existing = await (database.select(
      database.mediaItems,
    )..where((t) => t.id.equals(mediaItemId))).getSingle();
    final nextUpdatedAt = existing.updatedAt.add(const Duration(minutes: 5));

    await database.mediaDao.upsertItem(
      MediaItemsCompanion.insert(
        id: existing.id,
        mediaType: existing.mediaType,
        title: existing.title,
        subtitle: Value(existing.subtitle),
        posterUrl: Value(existing.posterUrl),
        releaseDate: Value(existing.releaseDate),
        overview: Value(existing.overview),
        sourceIdsJson: Value(existing.sourceIdsJson),
        runtimeMinutes: Value(existing.runtimeMinutes),
        totalEpisodes: Value(existing.totalEpisodes),
        totalPages: Value(existing.totalPages),
        estimatedPlayHours: Value(existing.estimatedPlayHours),
        createdAt: existing.createdAt,
        updatedAt: nextUpdatedAt,
        deletedAt: Value(nextUpdatedAt),
        syncVersion: Value(existing.syncVersion),
        deviceId: Value(existing.deviceId),
        lastSyncedAt: Value(existing.lastSyncedAt),
      ),
    );
  }

  Future<void> bumpUserEntryTimestamp(String mediaItemId) async {
    final existing = await database.userEntryDao.getByMediaItemId(mediaItemId);
    final nextUpdatedAt = existing!.updatedAt.add(const Duration(minutes: 5));

    await database.userEntryDao.upsert(
      UserEntriesCompanion.insert(
        id: existing.id,
        mediaItemId: existing.mediaItemId,
        status: Value(existing.status),
        score: Value(existing.score),
        review: Value(existing.review),
        notes: Value(existing.notes),
        favorite: Value(existing.favorite),
        reconsumeCount: Value(existing.reconsumeCount),
        startedAt: Value(existing.startedAt),
        finishedAt: Value(existing.finishedAt),
        createdAt: existing.createdAt,
        updatedAt: nextUpdatedAt,
        deletedAt: Value(existing.deletedAt),
        syncVersion: Value(existing.syncVersion),
        deviceId: Value(existing.deviceId),
        lastSyncedAt: Value(existing.lastSyncedAt),
      ),
    );
  }

  Future<void> setUserEntryFields(
    String mediaItemId, {
    String? notes,
    String? review,
    int? score,
    DateTime? updatedAt,
  }) async {
    final existing = await database.userEntryDao.getByMediaItemId(mediaItemId);
    final nextUpdatedAt = updatedAt ?? existing!.updatedAt;

    await database.userEntryDao.upsert(
      UserEntriesCompanion.insert(
        id: existing!.id,
        mediaItemId: existing.mediaItemId,
        status: Value(existing.status),
        score: Value(score ?? existing.score),
        review: Value(review ?? existing.review),
        notes: Value(notes ?? existing.notes),
        favorite: Value(existing.favorite),
        reconsumeCount: Value(existing.reconsumeCount),
        startedAt: Value(existing.startedAt),
        finishedAt: Value(existing.finishedAt),
        createdAt: existing.createdAt,
        updatedAt: nextUpdatedAt,
        deletedAt: Value(existing.deletedAt),
        syncVersion: Value(existing.syncVersion),
        deviceId: Value(existing.deviceId),
        lastSyncedAt: Value(existing.lastSyncedAt),
      ),
    );
  }
}

class _InMemorySyncStorageAdapter implements SyncStorageAdapter {
  final Map<String, _StoredRecord> _entityRecords = <String, _StoredRecord>{};
  final Map<String, _StoredRecord> _tombstoneRecords =
      <String, _StoredRecord>{};

  bool failWrites = false;

  @override
  Future<void> delete(String key) async {
    if (failWrites) {
      throw const SyncNetworkException('Network unavailable.');
    }

    final removedEntity = _entityRecords.remove(key);
    final removedTombstone = _tombstoneRecords.remove(key);
    if (removedEntity == null && removedTombstone == null) {
      throw const SyncRemoteNotFoundException('Remote record not found.');
    }
  }

  @override
  Future<List<SyncStorageRecordRef>> listRecords() async {
    return <SyncStorageRecordRef>[
      ..._entityRecords.entries.map(
        (entry) => SyncStorageRecordRef(
          key: entry.key,
          kind: SyncStorageRecordKind.entity,
          updatedAt: entry.value.updatedAt,
        ),
      ),
      ..._tombstoneRecords.entries.map(
        (entry) => SyncStorageRecordRef(
          key: entry.key,
          kind: SyncStorageRecordKind.tombstone,
          updatedAt: entry.value.updatedAt,
        ),
      ),
    ];
  }

  @override
  Future<String> readText(String key) async {
    final record = _entityRecords[key] ?? _tombstoneRecords[key];
    if (record == null) {
      throw const SyncRemoteNotFoundException('Remote record not found.');
    }
    return record.content;
  }

  @override
  Future<void> writeText({required String key, required String content}) async {
    if (failWrites) {
      throw const SyncNetworkException('Network unavailable.');
    }

    final envelope = SyncEntityEnvelope.fromJsonString(content);
    _entityRecords[key] = _StoredRecord(
      content: content,
      updatedAt: envelope.updatedAt,
    );
  }

  @override
  Future<void> writeTombstone({
    required String key,
    required String content,
  }) async {
    if (failWrites) {
      throw const SyncNetworkException('Network unavailable.');
    }

    final envelope = SyncEntityEnvelope.fromJsonString(content);
    _tombstoneRecords[key] = _StoredRecord(
      content: content,
      updatedAt: envelope.updatedAt,
    );
  }
}

class _StoredRecord {
  const _StoredRecord({required this.content, required this.updatedAt});

  final String content;
  final DateTime updatedAt;
}

import 'package:drift/drift.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/repositories/activity_log_repository.dart';
import '../../../shared/data/repositories/media_repository.dart';
import '../../../shared/data/repositories/progress_repository.dart';
import '../../../shared/data/repositories/shelf_repository.dart';
import '../../../shared/data/repositories/tag_repository.dart';
import '../../../shared/data/repositories/user_entry_repository.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_conflict.dart';
import 'sync_exception.dart';
import 'sync_merge_policy.dart';
import 'sync_models.dart';
import 'sync_queue.dart';
import 'sync_status.dart';
import 'sync_storage_adapter.dart';

class SyncApplyOutcome {
  const SyncApplyOutcome({required this.decision, required this.envelope});

  final SyncMergeDecision decision;
  final SyncEntityEnvelope envelope;
}

class SyncRecordDescriptor {
  const SyncRecordDescriptor({
    required this.entityType,
    required this.entityId,
    required this.kind,
  });

  final SyncEntityType entityType;
  final String entityId;
  final SyncStorageRecordKind kind;
}

class SyncCodec {
  SyncCodec({
    required AppDatabase database,
    required MediaRepository mediaRepository,
    required UserEntryRepository userEntryRepository,
    required ProgressRepository progressRepository,
    required TagRepository tagRepository,
    required ShelfRepository shelfRepository,
    required ActivityLogRepository activityLogRepository,
    SyncConflictRepository? conflictRepository,
    SyncStatusController? statusController,
    SyncMergePolicy mergePolicy = const SyncMergePolicy(),
    StepLogger? logger,
  }) : _database = database,
       _mediaRepository = mediaRepository,
       _userEntryRepository = userEntryRepository,
       _progressRepository = progressRepository,
       _tagRepository = tagRepository,
       _shelfRepository = shelfRepository,
       _activityLogRepository = activityLogRepository,
       _conflictRepository = conflictRepository,
       _statusController = statusController,
       _mergePolicy = mergePolicy,
       _logger = logger ?? const StepLogger('SyncCodec');

  final AppDatabase _database;
  final MediaRepository _mediaRepository;
  final UserEntryRepository _userEntryRepository;
  final ProgressRepository _progressRepository;
  final TagRepository _tagRepository;
  final ShelfRepository _shelfRepository;
  final ActivityLogRepository _activityLogRepository;
  final SyncConflictRepository? _conflictRepository;
  final SyncStatusController? _statusController;
  final SyncMergePolicy _mergePolicy;
  final StepLogger _logger;

  String buildEntityKey(SyncEntityType entityType, String entityId) {
    return 'entities/${entityType.name}/${Uri.encodeComponent(entityId)}.json';
  }

  String buildTombstoneKey(SyncEntityType entityType, String entityId) {
    return 'tombstones/${entityType.name}/${Uri.encodeComponent(entityId)}.json';
  }

  SyncRecordDescriptor parseRecordKey(String key, SyncStorageRecordKind kind) {
    final segments = key.split('/');
    if (segments.length != 3 || !segments.last.endsWith('.json')) {
      throw SyncFormatException('Invalid remote sync key: $key');
    }

    final entityTypeName = segments[1];
    final encodedId = segments[2].replaceFirst(RegExp(r'\.json$'), '');

    try {
      return SyncRecordDescriptor(
        entityType: SyncEntityType.values.byName(entityTypeName),
        entityId: Uri.decodeComponent(encodedId),
        kind: kind,
      );
    } on ArgumentError {
      throw SyncFormatException('Unknown sync entity type in key: $key');
    }
  }

  SyncEntityEnvelope decodeRemoteRecord({
    required SyncStorageRecordRef recordRef,
    required String content,
  }) {
    /*
     * ========================================================================
     * 步骤1：解码远端同步记录
     * ========================================================================
     * 目标：
     *   1) 把 storage adapter 读到的文本转换为统一 envelope
     *   2) 校验 key、kind 与 envelope 元信息一致
     */
    _logger.info('开始解码远端同步记录...');

    // 1.1 先解析 key，拿到 kind 与逻辑实体标识
    final descriptor = parseRecordKey(recordRef.key, recordRef.kind);
    final envelope = SyncEntityEnvelope.fromJsonString(content);

    if (descriptor.entityType != envelope.entityType ||
        descriptor.entityId != envelope.entityId) {
      _logger.info('远端同步记录解码失败。');
      throw SyncFormatException(
        'Remote sync record key does not match envelope payload.',
      );
    }

    if (descriptor.kind == SyncStorageRecordKind.tombstone &&
        envelope.deletedAt == null) {
      _logger.info('远端同步记录解码失败。');
      throw SyncFormatException('Tombstone record must carry deletedAt.');
    }

    _logger.info('远端同步记录解码完成。');
    return envelope;
  }

  Future<SyncEntityEnvelope> encodePendingItem(SyncQueueItem item) async {
    /*
     * ========================================================================
     * 步骤2：把本地待同步条目编码为统一快照
     * ========================================================================
     * 目标：
     *   1) 从当前数据库状态生成 push 用的统一 envelope
     *   2) 缺少实时行时回退到队列里已有的 snapshotJson
     */
    _logger.info('开始把本地待同步条目编码为统一快照...');

    // 2.1 先尝试读取当前数据库状态；缺失时回退队列快照
    final liveEnvelope = await _encodeFromDatabase(item);
    if (liveEnvelope != null) {
      _logger.info('本地待同步条目编码完成。');
      return liveEnvelope;
    }

    final snapshotJson = item.snapshotJson;
    if (snapshotJson != null && snapshotJson.isNotEmpty) {
      _logger.info('本地待同步条目编码完成。');
      return SyncEntityEnvelope.fromJsonString(snapshotJson);
    }

    _logger.info('本地待同步条目编码失败。');
    throw SyncFormatException(
      'Unable to build sync envelope for ${item.entityType.name}/${item.entityId}.',
    );
  }

  Future<SyncApplyOutcome> applyRemoteEnvelope(
    SyncEntityEnvelope envelope,
  ) async {
    /*
     * ========================================================================
     * 步骤3：应用远端同步快照到本地
     * ========================================================================
     * 目标：
     *   1) 在 engine 层做 last-modified merge 决策
     *   2) 只在需要时调用 repository 写回本地
     */
    _logger.info('开始应用远端同步快照到本地...');

    // 3.1 先读取本地状态，再按 merge policy 判断远端是否应落地
    final localState = await _readLocalState(
      entityType: envelope.entityType,
      entityId: envelope.entityId,
    );
    final decision = _mergePolicy.decide(
      localState: localState,
      remoteUpdatedAt: envelope.updatedAt,
      remoteDeviceId: envelope.deviceId,
    );

    if (decision == SyncMergeDecision.applyRemote) {
      await _recordTextConflictsIfNeeded(envelope, localState);
      await _applyEnvelope(envelope);
    } else {
      await _recordTextConflictsIfNeeded(envelope, localState);
    }

    _logger.info('远端同步快照应用完成。');
    return SyncApplyOutcome(decision: decision, envelope: envelope);
  }

  Future<void> markQueueItemSynced(
    SyncQueueItem item,
    DateTime syncedAt,
  ) async {
    /*
     * ========================================================================
     * 步骤4：回写本地同步戳
     * ========================================================================
     * 目标：
     *   1) 在 push 成功后把相应本地实体标记为已同步
     *   2) 继续复用 repository 已有的 markSynced 入口
     */
    _logger.info('开始回写本地同步戳...');

    // 4.1 按实体类型定位本地实体，再走各自的 markSynced 入口
    switch (item.entityType) {
      case SyncEntityType.mediaItem:
        await _mediaRepository.markSynced(item.entityId, syncedAt);
      case SyncEntityType.userEntry:
        final row = await (_database.select(
          _database.userEntries,
        )..where((t) => t.id.equals(item.entityId))).getSingleOrNull();
        if (row != null) {
          await _userEntryRepository.markSynced(row.mediaItemId, syncedAt);
        }
      case SyncEntityType.progressEntry:
        final row = await (_database.select(
          _database.progressEntries,
        )..where((t) => t.id.equals(item.entityId))).getSingleOrNull();
        if (row != null) {
          await _progressRepository.markSynced(row.mediaItemId, syncedAt);
        }
      case SyncEntityType.tag:
        await _tagRepository.markSynced(item.entityId, syncedAt);
      case SyncEntityType.shelf:
        await _shelfRepository.markSynced(item.entityId, syncedAt);
      case SyncEntityType.mediaItemTag:
        final row = await (_database.select(
          _database.mediaItemTags,
        )..where((t) => t.id.equals(item.entityId))).getSingleOrNull();
        if (row != null) {
          await _tagRepository.markTagLinkSynced(
            row.mediaItemId,
            row.tagId,
            syncedAt,
          );
        }
      case SyncEntityType.mediaItemShelf:
        final row = await (_database.select(
          _database.mediaItemShelves,
        )..where((t) => t.id.equals(item.entityId))).getSingleOrNull();
        if (row != null) {
          await _shelfRepository.markShelfLinkSynced(
            row.mediaItemId,
            row.shelfListId,
            syncedAt,
          );
        }
      case SyncEntityType.activityLog:
        await _activityLogRepository.markSynced(item.entityId, syncedAt);
    }

    _logger.info('本地同步戳回写完成。');
  }

  Future<SyncEntityEnvelope?> _encodeFromDatabase(SyncQueueItem item) async {
    switch (item.entityType) {
      case SyncEntityType.mediaItem:
        return _encodeMediaItem(item.entityId);
      case SyncEntityType.userEntry:
        return _encodeUserEntry(item.entityId);
      case SyncEntityType.progressEntry:
        return _encodeProgressEntry(item.entityId);
      case SyncEntityType.tag:
        return _encodeTag(item.entityId);
      case SyncEntityType.shelf:
        return _encodeShelf(item.entityId);
      case SyncEntityType.mediaItemTag:
        return _encodeMediaItemTag(item.entityId);
      case SyncEntityType.mediaItemShelf:
        return _encodeMediaItemShelf(item.entityId);
      case SyncEntityType.activityLog:
        return _encodeActivityLog(item.entityId);
    }
  }

  Future<SyncEntityEnvelope?> _encodeMediaItem(String localId) async {
    final row = await (_database.select(
      _database.mediaItems,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.mediaItem,
      entityId: row.id,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'mediaType': row.mediaType.name,
        'title': row.title,
        'subtitle': row.subtitle,
        'posterUrl': row.posterUrl,
        'releaseDate': _serializeDateTime(row.releaseDate),
        'overview': row.overview,
        'sourceIdsJson': row.sourceIdsJson,
        'runtimeMinutes': row.runtimeMinutes,
        'totalEpisodes': row.totalEpisodes,
        'totalPages': row.totalPages,
        'estimatedPlayHours': row.estimatedPlayHours,
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncEntityEnvelope?> _encodeUserEntry(String localId) async {
    final row = await (_database.select(
      _database.userEntries,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.userEntry,
      entityId: row.mediaItemId,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'status': row.status.name,
        'score': row.score,
        'review': row.review,
        'notes': row.notes,
        'favorite': row.favorite,
        'reconsumeCount': row.reconsumeCount,
        'startedAt': _serializeDateTime(row.startedAt),
        'finishedAt': _serializeDateTime(row.finishedAt),
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncEntityEnvelope?> _encodeProgressEntry(String localId) async {
    final row = await (_database.select(
      _database.progressEntries,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.progressEntry,
      entityId: row.mediaItemId,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'currentEpisode': row.currentEpisode,
        'currentPage': row.currentPage,
        'currentMinutes': row.currentMinutes,
        'completionRatio': row.completionRatio,
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncEntityEnvelope?> _encodeTag(String localId) async {
    final row = await (_database.select(
      _database.tags,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.tag,
      entityId: row.id,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'name': row.name,
        'color': row.color,
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncEntityEnvelope?> _encodeShelf(String localId) async {
    final row = await (_database.select(
      _database.shelfLists,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.shelf,
      entityId: row.id,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'name': row.name,
        'kind': row.kind.name,
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncEntityEnvelope?> _encodeMediaItemTag(String localId) async {
    final row = await (_database.select(
      _database.mediaItemTags,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.mediaItemTag,
      entityId: _composeLinkId(row.mediaItemId, row.tagId),
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'mediaItemId': row.mediaItemId,
        'tagId': row.tagId,
        'linkId': row.id,
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncEntityEnvelope?> _encodeMediaItemShelf(String localId) async {
    final row = await (_database.select(
      _database.mediaItemShelves,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.mediaItemShelf,
      entityId: _composeLinkId(row.mediaItemId, row.shelfListId),
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'mediaItemId': row.mediaItemId,
        'shelfListId': row.shelfListId,
        'linkId': row.id,
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncEntityEnvelope?> _encodeActivityLog(String localId) async {
    final row = await (_database.select(
      _database.activityLogs,
    )..where((t) => t.id.equals(localId))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    return SyncEntityEnvelope(
      entityType: SyncEntityType.activityLog,
      entityId: row.id,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      syncVersion: row.syncVersion,
      deviceId: row.deviceId,
      lastSyncedAt: row.lastSyncedAt,
      payload: <String, Object?>{
        'mediaItemId': row.mediaItemId,
        'event': row.event.name,
        'payloadJson': row.payloadJson,
        'createdAt': row.createdAt.toIso8601String(),
      },
    );
  }

  Future<SyncLocalState?> _readLocalState({
    required SyncEntityType entityType,
    required String entityId,
  }) async {
    switch (entityType) {
      case SyncEntityType.mediaItem:
        final row = await (_database.select(
          _database.mediaItems,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
      case SyncEntityType.userEntry:
        final row = await _database.userEntryDao.getByMediaItemId(entityId);
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
      case SyncEntityType.progressEntry:
        final row = await _database.progressDao.getByMediaItemId(entityId);
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
      case SyncEntityType.tag:
        final row = await (_database.select(
          _database.tags,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
      case SyncEntityType.shelf:
        final row = await (_database.select(
          _database.shelfLists,
        )..where((t) => t.id.equals(entityId))).getSingleOrNull();
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
      case SyncEntityType.mediaItemTag:
        final ids = _splitLinkId(entityId);
        final row =
            await (_database.select(_database.mediaItemTags)..where(
                  (t) => t.mediaItemId.equals(ids.$1) & t.tagId.equals(ids.$2),
                ))
                .getSingleOrNull();
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
      case SyncEntityType.mediaItemShelf:
        final ids = _splitLinkId(entityId);
        final row =
            await (_database.select(_database.mediaItemShelves)..where(
                  (t) =>
                      t.mediaItemId.equals(ids.$1) &
                      t.shelfListId.equals(ids.$2),
                ))
                .getSingleOrNull();
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
      case SyncEntityType.activityLog:
        final row = await _database.activityLogDao.getById(entityId);
        return _mapLocalState(
          row?.updatedAt,
          row?.deletedAt,
          row?.lastSyncedAt,
          row?.deviceId,
        );
    }
  }

  SyncLocalState? _mapLocalState(
    DateTime? updatedAt,
    DateTime? deletedAt,
    DateTime? lastSyncedAt,
    String? deviceId,
  ) {
    if (updatedAt == null || deviceId == null) {
      return null;
    }

    return SyncLocalState(
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      lastSyncedAt: lastSyncedAt,
      deviceId: deviceId,
    );
  }

  Future<void> _applyEnvelope(SyncEntityEnvelope envelope) async {
    switch (envelope.entityType) {
      case SyncEntityType.mediaItem:
        await _mediaRepository.applyRemoteSnapshot(
          mediaItemId: envelope.entityId,
          mediaType: MediaType.values.byName(
            _requireString(envelope.payload, 'mediaType'),
          ),
          title: _requireString(envelope.payload, 'title'),
          subtitle: _optionalString(envelope.payload, 'subtitle'),
          posterUrl: _optionalString(envelope.payload, 'posterUrl'),
          releaseDate: _optionalDateTime(envelope.payload, 'releaseDate'),
          overview: _optionalString(envelope.payload, 'overview'),
          sourceIdsJson: _optionalString(envelope.payload, 'sourceIdsJson'),
          runtimeMinutes: _optionalInt(envelope.payload, 'runtimeMinutes'),
          totalEpisodes: _optionalInt(envelope.payload, 'totalEpisodes'),
          totalPages: _optionalInt(envelope.payload, 'totalPages'),
          estimatedPlayHours: _optionalDouble(
            envelope.payload,
            'estimatedPlayHours',
          ),
          createdAt: _requireDateTime(envelope.payload, 'createdAt'),
          updatedAt: envelope.updatedAt,
          deletedAt: envelope.deletedAt,
          syncVersion: envelope.syncVersion,
          lastSyncedAt: envelope.updatedAt,
        );
      case SyncEntityType.userEntry:
        await _userEntryRepository.applyRemoteSnapshot(
          mediaItemId: envelope.entityId,
          createdAt: _requireDateTime(envelope.payload, 'createdAt'),
          updatedAt: envelope.updatedAt,
          status: UnifiedStatus.values.byName(
            _requireString(envelope.payload, 'status'),
          ),
          score: _optionalInt(envelope.payload, 'score'),
          review: _optionalString(envelope.payload, 'review'),
          notes: _optionalString(envelope.payload, 'notes'),
          favorite: _optionalBool(envelope.payload, 'favorite') ?? false,
          reconsumeCount: _optionalInt(envelope.payload, 'reconsumeCount') ?? 0,
          startedAt: _optionalDateTime(envelope.payload, 'startedAt'),
          finishedAt: _optionalDateTime(envelope.payload, 'finishedAt'),
          deletedAt: envelope.deletedAt,
          syncVersion: envelope.syncVersion,
          lastSyncedAt: envelope.updatedAt,
        );
      case SyncEntityType.progressEntry:
        await _progressRepository.applyRemoteSnapshot(
          mediaItemId: envelope.entityId,
          createdAt: _requireDateTime(envelope.payload, 'createdAt'),
          updatedAt: envelope.updatedAt,
          currentEpisode: _optionalInt(envelope.payload, 'currentEpisode'),
          currentPage: _optionalInt(envelope.payload, 'currentPage'),
          currentMinutes: _optionalDouble(envelope.payload, 'currentMinutes'),
          completionRatio: _optionalDouble(envelope.payload, 'completionRatio'),
          deletedAt: envelope.deletedAt,
          syncVersion: envelope.syncVersion,
          lastSyncedAt: envelope.updatedAt,
        );
      case SyncEntityType.tag:
        await _tagRepository.applyRemoteSnapshot(
          tagId: envelope.entityId,
          name: _requireString(envelope.payload, 'name'),
          color: _optionalString(envelope.payload, 'color'),
          createdAt: _requireDateTime(envelope.payload, 'createdAt'),
          updatedAt: envelope.updatedAt,
          deletedAt: envelope.deletedAt,
          syncVersion: envelope.syncVersion,
          lastSyncedAt: envelope.updatedAt,
        );
      case SyncEntityType.shelf:
        await _shelfRepository.applyRemoteSnapshot(
          shelfListId: envelope.entityId,
          name: _requireString(envelope.payload, 'name'),
          kind: ShelfKind.values.byName(
            _requireString(envelope.payload, 'kind'),
          ),
          createdAt: _requireDateTime(envelope.payload, 'createdAt'),
          updatedAt: envelope.updatedAt,
          deletedAt: envelope.deletedAt,
          syncVersion: envelope.syncVersion,
          lastSyncedAt: envelope.updatedAt,
        );
      case SyncEntityType.mediaItemTag:
        final mediaItemId = _requireString(envelope.payload, 'mediaItemId');
        final tagId = _requireString(envelope.payload, 'tagId');
        if (envelope.deletedAt != null) {
          await _tagRepository.applyRemoteDetachment(
            mediaItemId: mediaItemId,
            tagId: tagId,
            syncedAt: envelope.updatedAt,
          );
          return;
        }

        await _tagRepository.applyRemoteAttachment(
          mediaItemId: mediaItemId,
          tagId: tagId,
          linkId: _optionalString(envelope.payload, 'linkId'),
          syncedAt: envelope.updatedAt,
        );
      case SyncEntityType.mediaItemShelf:
        final mediaItemId = _requireString(envelope.payload, 'mediaItemId');
        final shelfListId = _requireString(envelope.payload, 'shelfListId');
        if (envelope.deletedAt != null) {
          await _shelfRepository.applyRemoteDetachment(
            mediaItemId: mediaItemId,
            shelfListId: shelfListId,
            syncedAt: envelope.updatedAt,
          );
          return;
        }

        await _shelfRepository.applyRemoteAttachment(
          mediaItemId: mediaItemId,
          shelfListId: shelfListId,
          linkId: _optionalString(envelope.payload, 'linkId'),
          syncedAt: envelope.updatedAt,
        );
      case SyncEntityType.activityLog:
        await _activityLogRepository.applyRemoteSnapshot(
          id: envelope.entityId,
          mediaItemId: _requireString(envelope.payload, 'mediaItemId'),
          event: ActivityEvent.values.byName(
            _requireString(envelope.payload, 'event'),
          ),
          payloadJson: _requireString(envelope.payload, 'payloadJson'),
          createdAt: _requireDateTime(envelope.payload, 'createdAt'),
          updatedAt: envelope.updatedAt,
          deletedAt: envelope.deletedAt,
          syncVersion: envelope.syncVersion,
          lastSyncedAt: envelope.updatedAt,
        );
    }
  }

  Future<void> _recordTextConflictsIfNeeded(
    SyncEntityEnvelope envelope,
    SyncLocalState? localState,
  ) async {
    final conflictRepository = _conflictRepository;
    if (conflictRepository == null ||
        envelope.entityType != SyncEntityType.userEntry ||
        localState == null ||
        localState.deviceId == envelope.deviceId) {
      return;
    }

    final localEntry = await _database.userEntryDao.getByMediaItemId(
      envelope.entityId,
    );
    if (localEntry == null || !_isIndependentTextChange(localEntry, envelope)) {
      return;
    }

    final hasNotesConflict = await _recordTextConflict(
      conflictRepository: conflictRepository,
      envelope: envelope,
      localEntry: localEntry,
      fieldName: 'notes',
    );
    final hasReviewConflict = await _recordTextConflict(
      conflictRepository: conflictRepository,
      envelope: envelope,
      localEntry: localEntry,
      fieldName: 'review',
    );

    if (hasNotesConflict || hasReviewConflict) {
      await _statusController?.markHasConflicts();
    }
  }

  bool _isIndependentTextChange(
    UserEntry localEntry,
    SyncEntityEnvelope envelope,
  ) {
    final lastSyncedAt = localEntry.lastSyncedAt;
    if (lastSyncedAt == null) {
      return true;
    }

    return localEntry.updatedAt.isAfter(lastSyncedAt) &&
        envelope.updatedAt.isAfter(lastSyncedAt);
  }

  Future<bool> _recordTextConflict({
    required SyncConflictRepository conflictRepository,
    required SyncEntityEnvelope envelope,
    required UserEntry localEntry,
    required String fieldName,
  }) async {
    final localValue = switch (fieldName) {
      'notes' => localEntry.notes,
      'review' => localEntry.review,
      _ => throw SyncFormatException('Unsupported text conflict field.'),
    };
    final remoteValue = _optionalString(envelope.payload, fieldName);

    if (localValue == remoteValue) {
      return false;
    }

    await conflictRepository.recordTextConflict(
      entityType: envelope.entityType,
      entityId: envelope.entityId,
      fieldName: fieldName,
      localValue: localValue,
      remoteValue: remoteValue,
      localUpdatedAt: localEntry.updatedAt,
      remoteUpdatedAt: envelope.updatedAt,
      localDeviceId: localEntry.deviceId,
      remoteDeviceId: envelope.deviceId,
    );
    return true;
  }

  String _composeLinkId(String left, String right) => '$left::$right';

  (String, String) _splitLinkId(String value) {
    final parts = value.split('::');
    if (parts.length != 2) {
      throw SyncFormatException('Invalid sync link id: $value');
    }

    return (parts[0], parts[1]);
  }

  String _requireString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value is! String || value.isEmpty) {
      throw SyncFormatException('Missing string field: $key');
    }
    return value;
  }

  String? _optionalString(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw SyncFormatException('Invalid string field: $key');
    }
    return value;
  }

  int? _optionalInt(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw SyncFormatException('Invalid int field: $key');
  }

  double? _optionalDouble(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    throw SyncFormatException('Invalid double field: $key');
  }

  bool? _optionalBool(Map<String, Object?> payload, String key) {
    final value = payload[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw SyncFormatException('Invalid bool field: $key');
  }

  DateTime _requireDateTime(Map<String, Object?> payload, String key) {
    final rawValue = _requireString(payload, key);
    return DateTime.parse(rawValue);
  }

  DateTime? _optionalDateTime(Map<String, Object?> payload, String key) {
    final rawValue = _optionalString(payload, key);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return DateTime.parse(rawValue);
  }

  String? _serializeDateTime(DateTime? value) {
    return value?.toIso8601String();
  }
}

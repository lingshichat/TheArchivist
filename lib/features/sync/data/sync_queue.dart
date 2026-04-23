import 'package:drift/drift.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/device_identity.dart';
import '../../../shared/data/sync_stamp.dart';
import '../../../shared/utils/step_logger.dart';
import 'sync_models.dart';

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.createdAt,
    required this.updatedAt,
    required this.retryCount,
    required this.deviceId,
    this.snapshotJson,
    this.lastAttemptedAt,
    this.errorSummary,
    this.completedAt,
  });

  final String id;
  final SyncEntityType entityType;
  final String entityId;
  final SyncOperationType operation;
  final String? snapshotJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAttemptedAt;
  final int retryCount;
  final String? errorSummary;
  final DateTime? completedAt;
  final String deviceId;

  bool get isCompleted => completedAt != null;
}

class SyncQueueRepository {
  SyncQueueRepository({
    required AppDatabase database,
    required DeviceIdentityService deviceIdentityService,
    StepLogger? logger,
  }) : _database = database,
       _deviceIdentityService = deviceIdentityService,
       _logger = logger ?? const StepLogger('SyncQueueRepository');

  final AppDatabase _database;
  final DeviceIdentityService _deviceIdentityService;
  final StepLogger _logger;

  Stream<int> watchPendingCount() {
    return _database.syncQueueDao.watchPendingCount();
  }

  Future<List<SyncChangeCandidate>> listChangeCandidates({
    int limit = 100,
  }) async {
    /*
     * ========================================================================
     * 步骤1：扫描本地待同步变更
     * ========================================================================
     * 目标：
     *   1) 把首版 dirty rules 落成真正可复用的本地扫描入口
     *   2) 给后续 push engine 复用统一的候选对象列表
     */
    _logger.info('开始扫描本地待同步变更...');

    // 1.1 汇总所有 sync-capable 表的候选对象
    final candidates = <SyncChangeCandidate>[
      ...await _scanMediaItems(),
      ...await _scanUserEntries(),
      ...await _scanProgressEntries(),
      ...await _scanTags(),
      ...await _scanShelfLists(),
      ...await _scanMediaItemTags(),
      ...await _scanMediaItemShelves(),
      ...await _scanActivityLogs(),
    ];

    // 1.2 只保留 dirty rules 命中的对象，并按更新时间排序
    final dirtyCandidates = candidates.where((item) => item.needsSync).toList();
    dirtyCandidates.sort((left, right) {
      final timeCompare = left.updatedAt.compareTo(right.updatedAt);
      if (timeCompare != 0) {
        return timeCompare;
      }

      final typeCompare = left.entityType.name.compareTo(right.entityType.name);
      if (typeCompare != 0) {
        return typeCompare;
      }

      return left.entityId.compareTo(right.entityId);
    });

    _logger.info('本地待同步变更扫描完成。');
    return dirtyCandidates.take(limit).toList(growable: false);
  }

  Future<List<SyncQueueItem>> listPending({int limit = 100}) async {
    final rows = await _database.syncQueueDao.listPending(limit: limit);
    return rows.map(_mapQueueItem).toList(growable: false);
  }

  Future<List<SyncQueueItem>> enqueuePendingChanges({int limit = 100}) async {
    /*
     * ========================================================================
     * 步骤2：把本地变更批量入队
     * ========================================================================
     * 目标：
     *   1) 把扫描出的 dirty 对象统一转换成同步队列条目
     *   2) 让后续引擎直接消费同一份最小队列合同
     */
    _logger.info('开始批量写入本地变更队列...');

    // 2.1 先扫描 dirty candidate，再逐条写入队列
    final candidates = await listChangeCandidates(limit: limit);
    final queueItems = <SyncQueueItem>[];
    for (final candidate in candidates) {
      queueItems.add(
        await enqueue(
          entityType: candidate.entityType,
          entityId: candidate.entityId,
          operation: candidate.deletedAt != null
              ? SyncOperationType.delete
              : SyncOperationType.upsert,
        ),
      );
    }

    _logger.info('本地变更队列批量写入完成。');
    return queueItems;
  }

  Future<SyncQueueItem> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operation,
    SyncEntityEnvelope? snapshot,
  }) async {
    /*
     * ========================================================================
     * 步骤1：写入本地同步队列
     * ========================================================================
     * 目标：
     *   1) 为待上传对象建立最小持久化队列
     *   2) 对同一对象的同一操作做去重复用
     */
    _logger.info('开始写入本地同步队列...');

    // 1.1 命中未完成旧条目时复用同一行，只刷新快照和更新时间
    final existing = await _database.syncQueueDao.findPendingByEntity(
      entityType: entityType.name,
      entityId: entityId,
      operation: operation.name,
    );
    final now = SyncStampDecorator.now();
    final deviceId = await _deviceIdentityService.getOrCreateCurrentDeviceId();

    if (existing != null) {
      await _database.syncQueueDao.upsert(
        SyncQueueEntriesCompanion.insert(
          id: existing.id,
          entityType: entityType.name,
          entityId: entityId,
          operation: operation.name,
          snapshotJson: Value(snapshot?.toJsonString()),
          createdAt: existing.createdAt,
          updatedAt: now,
          lastAttemptedAt: Value(existing.lastAttemptedAt),
          retryCount: const Value(0),
          errorSummary: const Value(null),
          completedAt: const Value(null),
          deviceId: Value(deviceId),
        ),
      );

      final refreshed = await _database.syncQueueDao.findPendingByEntity(
        entityType: entityType.name,
        entityId: entityId,
        operation: operation.name,
      );
      _logger.info('本地同步队列写入完成。');
      return _mapQueueItem(refreshed!);
    }

    // 1.2 未命中时插入新队列条目
    final id = DeviceIdentityService.generate();
    await _database.syncQueueDao.upsert(
      SyncQueueEntriesCompanion.insert(
        id: id,
        entityType: entityType.name,
        entityId: entityId,
        operation: operation.name,
        snapshotJson: Value(snapshot?.toJsonString()),
        createdAt: now,
        updatedAt: now,
        retryCount: const Value(0),
        deviceId: Value(deviceId),
      ),
    );

    final created = await _database.syncQueueDao.findPendingByEntity(
      entityType: entityType.name,
      entityId: entityId,
      operation: operation.name,
    );
    _logger.info('本地同步队列写入完成。');
    return _mapQueueItem(created!);
  }

  Future<void> recordAttempt({
    required String queueItemId,
    required int retryCount,
    String? errorSummary,
  }) async {
    /*
     * ========================================================================
     * 步骤2：记录队列执行尝试结果
     * ========================================================================
     * 目标：
     *   1) 保存最近尝试时间与重试次数
     *   2) 为失败重试和最小状态面板保留摘要
     */
    _logger.info('开始记录队列执行尝试结果...');

    // 2.1 用统一 DAO 入口刷新尝试摘要
    final attemptedAt = SyncStampDecorator.now();
    await _database.syncQueueDao.recordAttempt(
      id: queueItemId,
      attemptedAt: attemptedAt,
      retryCount: retryCount,
      errorSummary: _normalizeOptional(errorSummary),
    );

    _logger.info('队列执行尝试结果记录完成。');
  }

  Future<void> markCompleted(String queueItemId) async {
    /*
     * ========================================================================
     * 步骤3：标记队列条目完成
     * ========================================================================
     * 目标：
     *   1) 在对象同步成功后结束本地待处理条目
     *   2) 保留完成时间供后续状态聚合使用
     */
    _logger.info('开始标记队列条目完成...');

    // 3.1 写入完成时间并结束该队列条目
    await _database.syncQueueDao.markCompleted(
      id: queueItemId,
      completedAt: SyncStampDecorator.now(),
    );

    _logger.info('队列条目完成标记完成。');
  }

  SyncQueueItem _mapQueueItem(SyncQueueEntry row) {
    return SyncQueueItem(
      id: row.id,
      entityType: SyncEntityType.values.byName(row.entityType),
      entityId: row.entityId,
      operation: SyncOperationType.values.byName(row.operation),
      snapshotJson: row.snapshotJson,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastAttemptedAt: row.lastAttemptedAt,
      retryCount: row.retryCount,
      errorSummary: row.errorSummary,
      completedAt: row.completedAt,
      deviceId: row.deviceId,
    );
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<List<SyncChangeCandidate>> _scanMediaItems() async {
    final rows = await _database.select(_database.mediaItems).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.mediaItem,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeCandidate>> _scanUserEntries() async {
    final rows = await _database.select(_database.userEntries).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.userEntry,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeCandidate>> _scanProgressEntries() async {
    final rows = await _database.select(_database.progressEntries).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.progressEntry,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeCandidate>> _scanTags() async {
    final rows = await _database.select(_database.tags).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.tag,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeCandidate>> _scanShelfLists() async {
    final rows = await _database.select(_database.shelfLists).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.shelf,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeCandidate>> _scanMediaItemTags() async {
    final rows = await _database.select(_database.mediaItemTags).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.mediaItemTag,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeCandidate>> _scanMediaItemShelves() async {
    final rows = await _database.select(_database.mediaItemShelves).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.mediaItemShelf,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }

  Future<List<SyncChangeCandidate>> _scanActivityLogs() async {
    final rows = await _database.select(_database.activityLogs).get();
    return rows
        .map(
          (row) => SyncChangeCandidate(
            entityType: SyncEntityType.activityLog,
            entityId: row.id,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
            deviceId: row.deviceId,
            lastSyncedAt: row.lastSyncedAt,
          ),
        )
        .toList(growable: false);
  }
}

import '../../../shared/utils/step_logger.dart';
import 'sync_codec.dart';
import 'sync_exception.dart';
import 'sync_merge_policy.dart';
import 'sync_models.dart';
import 'sync_queue.dart';
import 'sync_status.dart';
import 'sync_storage_adapter.dart';
import 'sync_summary.dart';

class SyncEngine {
  SyncEngine({
    required SyncQueueRepository queueRepository,
    required SyncStatusController statusController,
    required SyncCodec codec,
    StepLogger? logger,
  }) : _queueRepository = queueRepository,
       _statusController = statusController,
       _codec = codec,
       _logger = logger ?? const StepLogger('SyncEngine');

  final SyncQueueRepository _queueRepository;
  final SyncStatusController _statusController;
  final SyncCodec _codec;
  final StepLogger _logger;

  Future<SyncSummary> runSync({
    required SyncStorageAdapter adapter,
    int batchSize = 100,
  }) async {
    /*
     * ========================================================================
     * 步骤1：执行一轮完整的 push / pull 编排
     * ========================================================================
     * 目标：
     *   1) 把本地队列 push 到远端，再把远端记录 pull 回本地
     *   2) 统一汇总 summary，并把最小状态回写到 sync status
     */
    _logger.info('开始执行一轮完整的 push / pull 编排...');

    // 1.1 先把最新脏数据补进队列，再进入 running 状态
    await _queueRepository.enqueuePendingChanges(limit: batchSize);
    await _statusController.markRunning();

    final summaryBuilder = SyncSummaryBuilder();

    // 1.2 先执行 push，再执行 pull；任一阶段的失败都只记 summary
    await _runPushPhase(
      adapter: adapter,
      batchSize: batchSize,
      summaryBuilder: summaryBuilder,
    );
    await _statusController.refreshPendingCount();

    await _runPullPhase(adapter: adapter, summaryBuilder: summaryBuilder);

    final summary = summaryBuilder.build();
    await _statusController.markCompleted(
      errorSummary: summary.lastErrorSummary,
    );

    _logger.info('完整的 push / pull 编排执行完成。');
    return summary;
  }

  Future<void> _runPushPhase({
    required SyncStorageAdapter adapter,
    required int batchSize,
    required SyncSummaryBuilder summaryBuilder,
  }) async {
    /*
     * ========================================================================
     * 步骤2：执行本地增量上传
     * ========================================================================
     * 目标：
     *   1) 顺序消费本地待同步队列，写入实体快照或 tombstone
     *   2) 成功后回写 lastSyncedAt，失败后记录重试摘要
     */
    _logger.info('开始执行本地增量上传...');

    // 2.1 读取当前批次待处理队列条目
    final pendingItems = await _queueRepository.listPending(limit: batchSize);
    summaryBuilder.queuedCount = pendingItems.length;

    for (final item in pendingItems) {
      try {
        // 2.2 编码当前实体快照，并按操作类型写入远端
        final envelope = await _codec.encodePendingItem(item);
        final entityKey = _codec.buildEntityKey(
          envelope.entityType,
          envelope.entityId,
        );
        final tombstoneKey = _codec.buildTombstoneKey(
          envelope.entityType,
          envelope.entityId,
        );
        final content = envelope.toJsonString();

        if (item.operation == SyncOperationType.delete ||
            envelope.deletedAt != null) {
          await adapter.writeTombstone(key: tombstoneKey, content: content);
          await adapter.delete(entityKey);
          summaryBuilder.recordPushSuccess(deleted: true);
        } else {
          await adapter.writeText(key: entityKey, content: content);
          await _deleteQuietly(adapter, tombstoneKey);
          summaryBuilder.recordPushSuccess(deleted: false);
        }

        // 2.3 远端写入成功后回写本地同步戳，并结束该队列条目
        await _codec.markQueueItemSynced(item, envelope.updatedAt);
        await _queueRepository.markCompleted(item.id);
      } on SyncAuthException catch (error) {
        await _recordQueueFailure(item: item, message: error.message);
        summaryBuilder.recordFailure(error.message);
        break;
      } on SyncException catch (error) {
        await _recordQueueFailure(item: item, message: error.message);
        summaryBuilder.recordFailure(error.message);
      } catch (error) {
        final message = 'Push failed unexpectedly: $error';
        await _recordQueueFailure(item: item, message: message);
        summaryBuilder.recordFailure(message);
      }
    }

    _logger.info('本地增量上传执行完成。');
  }

  Future<void> _runPullPhase({
    required SyncStorageAdapter adapter,
    required SyncSummaryBuilder summaryBuilder,
  }) async {
    /*
     * ========================================================================
     * 步骤3：执行远端增量拉取
     * ========================================================================
     * 目标：
     *   1) 读取远端对象与 tombstone，并按 merge policy 合并到本地
     *   2) 统一汇总 applied / skipped / localWins / failed
     */
    _logger.info('开始执行远端增量拉取...');

    // 3.1 先列举远端记录，并按依赖顺序与更新时间排序
    final recordRefs = await adapter.listRecords();
    final sortedRecordRefs = [...recordRefs]..sort(_compareRecordRef);

    for (final recordRef in sortedRecordRefs) {
      try {
        // 3.2 解码远端记录，并按 merge policy 决定是否落地
        final content = await adapter.readText(recordRef.key);
        final envelope = _codec.decodeRemoteRecord(
          recordRef: recordRef,
          content: content,
        );
        final outcome = await _codec.applyRemoteEnvelope(envelope);

        switch (outcome.decision) {
          case SyncMergeDecision.applyRemote:
            summaryBuilder.recordPullApplied();
          case SyncMergeDecision.skip:
            summaryBuilder.recordPullSkipped();
          case SyncMergeDecision.localWins:
            summaryBuilder.recordLocalWins();
        }
      } on SyncAuthException catch (error) {
        summaryBuilder.recordFailure(error.message);
        break;
      } on SyncException catch (error) {
        summaryBuilder.recordFailure(error.message);
      } catch (error) {
        summaryBuilder.recordFailure('Pull failed unexpectedly: $error');
      }
    }

    _logger.info('远端增量拉取执行完成。');
  }

  int _compareRecordRef(SyncStorageRecordRef left, SyncStorageRecordRef right) {
    final timeCompare = left.updatedAt.compareTo(right.updatedAt);
    if (timeCompare != 0) {
      return timeCompare;
    }

    final leftDescriptor = _codec.parseRecordKey(left.key, left.kind);
    final rightDescriptor = _codec.parseRecordKey(right.key, right.kind);
    final orderCompare = _entitySortOrder(
      leftDescriptor.entityType,
    ).compareTo(_entitySortOrder(rightDescriptor.entityType));
    if (orderCompare != 0) {
      return orderCompare;
    }

    return left.key.compareTo(right.key);
  }

  int _entitySortOrder(SyncEntityType entityType) {
    switch (entityType) {
      case SyncEntityType.mediaItem:
        return 0;
      case SyncEntityType.tag:
        return 1;
      case SyncEntityType.shelf:
        return 2;
      case SyncEntityType.userEntry:
        return 3;
      case SyncEntityType.progressEntry:
        return 4;
      case SyncEntityType.activityLog:
        return 5;
      case SyncEntityType.mediaItemTag:
        return 6;
      case SyncEntityType.mediaItemShelf:
        return 7;
    }
  }

  Future<void> _recordQueueFailure({
    required SyncQueueItem item,
    required String message,
  }) async {
    await _queueRepository.recordAttempt(
      queueItemId: item.id,
      retryCount: item.retryCount + 1,
      errorSummary: message,
    );
  }

  Future<void> _deleteQuietly(SyncStorageAdapter adapter, String key) async {
    try {
      await adapter.delete(key);
    } on SyncRemoteNotFoundException {
      return;
    } on SyncException {
      return;
    }
  }
}

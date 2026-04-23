import 'package:drift/drift.dart';

import '../app_database.dart';
import '../../utils/step_logger.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueueEntries])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  static const StepLogger _logger = StepLogger('SyncQueueDao');

  Future<void> upsert(SyncQueueEntriesCompanion entry) {
    return into(syncQueueEntries).insertOnConflictUpdate(entry);
  }

  Future<List<SyncQueueEntry>> listPending({int limit = 100}) {
    return (select(syncQueueEntries)
          ..where((t) => t.completedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(limit))
        .get();
  }

  Stream<int> watchPendingCount() {
    final pendingCount = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([pendingCount])
      ..where(syncQueueEntries.completedAt.isNull());

    return query.watchSingle().map((row) => row.read(pendingCount) ?? 0);
  }

  Future<SyncQueueEntry?> findPendingByEntity({
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return (select(syncQueueEntries)..where(
      (t) =>
          t.entityType.equals(entityType) &
          t.entityId.equals(entityId) &
          t.operation.equals(operation) &
          t.completedAt.isNull(),
    )).getSingleOrNull();
  }

  Future<void> recordAttempt({
    required String id,
    required DateTime attemptedAt,
    required int retryCount,
    required String? errorSummary,
  }) async {
    /*
     * ========================================================================
     * 步骤1：记录同步队列一次执行尝试
     * ========================================================================
     * 目标：
     *   1) 保留最近尝试时间、重试次数和失败摘要
     *   2) 供后续引擎和状态面板复用同一持久化合同
     */
    _logger.info('开始记录同步队列执行尝试...');

    // 1.1 仅更新尝试相关字段
    await (update(syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        updatedAt: Value(attemptedAt),
        lastAttemptedAt: Value(attemptedAt),
        retryCount: Value(retryCount),
        errorSummary: Value(errorSummary),
      ),
    );

    _logger.info('同步队列执行尝试记录完成。');
  }

  Future<void> markCompleted({
    required String id,
    required DateTime completedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤2：标记同步队列条目完成
     * ========================================================================
     * 目标：
     *   1) 在成功执行后将队列条目标记为已完成
     *   2) 保留尝试历史与错误摘要用于追踪
     */
    _logger.info('开始标记同步队列条目完成...');

    // 2.1 写入完成时间并清空失败摘要
    await (update(syncQueueEntries)..where((t) => t.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        updatedAt: Value(completedAt),
        completedAt: Value(completedAt),
        errorSummary: const Value(null),
      ),
    );

    _logger.info('同步队列条目完成标记完成。');
  }
}

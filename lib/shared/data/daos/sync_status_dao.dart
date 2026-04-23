import 'package:drift/drift.dart';

import '../app_database.dart';
import '../../utils/step_logger.dart';

part 'sync_status_dao.g.dart';

@DriftAccessor(tables: [SyncStatusEntries])
class SyncStatusDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStatusDaoMixin {
  SyncStatusDao(super.db);

  static const StepLogger _logger = StepLogger('SyncStatusDao');

  Future<SyncStatusEntry?> getById(String id) {
    return (select(syncStatusEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<SyncStatusEntry?> watchById(String id) {
    return (select(syncStatusEntries)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<void> upsert(SyncStatusEntriesCompanion entry) {
    return into(syncStatusEntries).insertOnConflictUpdate(entry);
  }

  Future<void> updateSnapshot({
    required String id,
    required bool isRunning,
    required DateTime updatedAt,
    required int pendingCount,
    required bool hasConflicts,
    DateTime? lastCompletedAt,
    String? lastErrorSummary,
  }) async {
    /*
     * ========================================================================
     * 步骤1：更新同步状态快照
     * ========================================================================
     * 目标：
     *   1) 持久化最小同步运行状态
     *   2) 为设置页和后续状态中心提供稳定本地来源
     */
    _logger.info('开始更新同步状态快照...');

    // 1.1 统一覆盖当前同步运行摘要
    await upsert(
      SyncStatusEntriesCompanion.insert(
        id: id,
        isRunning: Value(isRunning),
        lastCompletedAt: Value(lastCompletedAt),
        lastErrorSummary: Value(lastErrorSummary),
        pendingCount: Value(pendingCount),
        hasConflicts: Value(hasConflicts),
        updatedAt: updatedAt,
      ),
    );

    _logger.info('同步状态快照更新完成。');
  }
}

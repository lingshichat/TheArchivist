import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/progress_entries.dart';
import '../../utils/step_logger.dart';

part 'progress_dao.g.dart';

@DriftAccessor(tables: [ProgressEntries])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  static const StepLogger _logger = StepLogger('ProgressDao');

  Stream<ProgressEntry?> watchByMediaItemId(String mediaItemId) {
    return (select(
      progressEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).watchSingleOrNull();
  }

  Future<ProgressEntry?> getByMediaItemId(String mediaItemId) {
    return (select(
      progressEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).getSingleOrNull();
  }

  Future<void> upsert(ProgressEntriesCompanion entry) {
    return into(progressEntries).insertOnConflictUpdate(entry);
  }

  Future<void> updateProgress(
    String mediaItemId,
    String deviceId, {
    int? currentEpisode,
    int? currentPage,
    double? currentMinutes,
    double? completionRatio,
  }) {
    final now = DateTime.now();
    return (update(
      progressEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      ProgressEntriesCompanion(
        currentEpisode: Value(currentEpisode),
        currentPage: Value(currentPage),
        currentMinutes: Value(currentMinutes),
        completionRatio: Value(completionRatio),
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> markSynced(
    String mediaItemId,
    DateTime syncedAt,
    String deviceId,
  ) async {
    /*
     * ========================================================================
     * 步骤1：更新进度条目的 lastSyncedAt
     * ========================================================================
     * 目标：
     *   1) 为 progress 的 pull / push 记录最近同步时间
     *   2) 不让单纯的同步标记污染业务字段
     */
    _logger.info('开始更新进度条目的 lastSyncedAt...');

    // 1.1 仅更新同步标记字段
    await (update(
      progressEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      ProgressEntriesCompanion(
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('进度条目的 lastSyncedAt 更新完成。');
  }
}

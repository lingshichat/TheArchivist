import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/activity_logs.dart';
import '../../utils/step_logger.dart';

part 'activity_log_dao.g.dart';

@DriftAccessor(tables: [ActivityLogs])
class ActivityLogDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityLogDaoMixin {
  ActivityLogDao(super.db);

  static const StepLogger _logger = StepLogger('ActivityLogDao');

  Stream<List<ActivityLog>> watchByMediaItemId(String mediaItemId) {
    return (select(activityLogs)
          ..where((t) => t.mediaItemId.equals(mediaItemId))
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<void> insertLog(ActivityLogsCompanion log) {
    return into(activityLogs).insert(log);
  }

  Future<ActivityLog?> getById(String id) {
    return (select(
      activityLogs,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(ActivityLogsCompanion log) {
    return into(activityLogs).insertOnConflictUpdate(log);
  }

  Future<void> markSynced(String id, DateTime syncedAt, String deviceId) async {
    /*
     * ========================================================================
     * 步骤1：更新活动日志的 lastSyncedAt
     * ========================================================================
     * 目标：
     *   1) 为活动日志的 pull / push 记录最近同步时间
     *   2) 不改写日志的事件内容与业务时间
     */
    _logger.info('开始更新活动日志的 lastSyncedAt...');

    // 1.1 仅更新同步标记字段
    await (update(activityLogs)..where((t) => t.id.equals(id))).write(
      ActivityLogsCompanion(
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('活动日志的 lastSyncedAt 更新完成。');
  }
}

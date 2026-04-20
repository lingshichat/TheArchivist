import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/activity_logs.dart';

part 'activity_log_dao.g.dart';

@DriftAccessor(tables: [ActivityLogs])
class ActivityLogDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityLogDaoMixin {
  ActivityLogDao(super.db);

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
}

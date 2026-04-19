import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/progress_entries.dart';

part 'progress_dao.g.dart';

@DriftAccessor(tables: [ProgressEntries])
class ProgressDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressDaoMixin {
  ProgressDao(super.db);

  Stream<ProgressEntry> watchByMediaItemId(String mediaItemId) {
    return (select(progressEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .watchSingle();
  }

  Future<ProgressEntry?> getByMediaItemId(String mediaItemId) {
    return (select(progressEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .getSingleOrNull();
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
    return (update(progressEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .write(
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
}

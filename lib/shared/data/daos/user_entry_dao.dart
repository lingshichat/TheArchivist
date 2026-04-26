import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/user_entries.dart';
import '../../utils/step_logger.dart';

part 'user_entry_dao.g.dart';

@DriftAccessor(tables: [UserEntries])
class UserEntryDao extends DatabaseAccessor<AppDatabase>
    with _$UserEntryDaoMixin {
  UserEntryDao(super.db);

  static const StepLogger _logger = StepLogger('UserEntryDao');

  Stream<UserEntry?> watchByMediaItemId(String mediaItemId) {
    return (select(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).watchSingleOrNull();
  }

  Future<UserEntry?> getByMediaItemId(String mediaItemId) {
    return (select(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).getSingleOrNull();
  }

  Future<void> upsert(UserEntriesCompanion entry) {
    return into(userEntries).insertOnConflictUpdate(entry);
  }

  Future<void> updateStatus(
    String mediaItemId,
    UnifiedStatus status,
    String deviceId,
    Value<DateTime?> startedAt,
    Value<DateTime?> finishedAt,
  ) {
    final now = DateTime.now();
    return (update(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      UserEntriesCompanion(
        status: Value(status),
        startedAt: startedAt,
        finishedAt: finishedAt,
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> updateScore(String mediaItemId, int? score, String deviceId) {
    final now = DateTime.now();
    return (update(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      UserEntriesCompanion(
        score: Value(score),
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> updateNotes(String mediaItemId, String? notes, String deviceId) {
    final now = DateTime.now();
    return (update(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      UserEntriesCompanion(
        notes: Value(notes),
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> updateReview(
    String mediaItemId,
    String? review,
    String deviceId,
  ) {
    final now = DateTime.now();
    return (update(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      UserEntriesCompanion(
        review: Value(review),
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> toggleFavorite(
    String mediaItemId,
    bool favorite,
    String deviceId,
  ) {
    final now = DateTime.now();
    return (update(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      UserEntriesCompanion(
        favorite: Value(favorite),
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
     * 步骤1：更新用户条目的 lastSyncedAt
     * ========================================================================
     * 目标：
     *   1) 为状态 / 评分的 pull、push 记录最近同步时间
     *   2) 不让单纯的同步标记污染业务字段
     */
    _logger.info('开始更新用户条目的 lastSyncedAt...');

    // 1.1 仅更新同步标记字段
    await (update(
      userEntries,
    )..where((t) => t.mediaItemId.equals(mediaItemId))).write(
      UserEntriesCompanion(
        deviceId: Value(deviceId),
        lastSyncedAt: Value(syncedAt),
      ),
    );

    _logger.info('用户条目的 lastSyncedAt 更新完成。');
  }
}

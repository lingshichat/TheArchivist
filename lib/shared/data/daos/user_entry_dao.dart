import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/user_entries.dart';

part 'user_entry_dao.g.dart';

@DriftAccessor(tables: [UserEntries])
class UserEntryDao extends DatabaseAccessor<AppDatabase>
    with _$UserEntryDaoMixin {
  UserEntryDao(super.db);

  Stream<UserEntry> watchByMediaItemId(String mediaItemId) {
    return (select(userEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .watchSingle();
  }

  Future<UserEntry?> getByMediaItemId(String mediaItemId) {
    return (select(userEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .getSingleOrNull();
  }

  Future<void> upsert(UserEntriesCompanion entry) {
    return into(userEntries).insertOnConflictUpdate(entry);
  }

  Future<void> updateStatus(
    String mediaItemId,
    UnifiedStatus status,
    String deviceId,
  ) {
    final now = DateTime.now();
    return (update(userEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .write(
      UserEntriesCompanion(
        status: Value(status),
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> updateScore(
    String mediaItemId,
    int? score,
    String deviceId,
  ) {
    final now = DateTime.now();
    return (update(userEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .write(
      UserEntriesCompanion(
        score: Value(score),
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }

  Future<void> updateNotes(
    String mediaItemId,
    String? notes,
    String deviceId,
  ) {
    final now = DateTime.now();
    return (update(userEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .write(
      UserEntriesCompanion(
        notes: Value(notes),
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
    return (update(userEntries)
          ..where((t) => t.mediaItemId.equals(mediaItemId)))
        .write(
      UserEntriesCompanion(
        favorite: Value(favorite),
        updatedAt: Value(now),
        deviceId: Value(deviceId),
      ),
    );
  }
}

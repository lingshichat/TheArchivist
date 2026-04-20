import 'package:drift/drift.dart';

import '../app_database.dart';

class UserEntryRepository {
  final AppDatabase _db;

  UserEntryRepository(this._db);

  Stream<UserEntry?> watchByMediaItemId(String mediaItemId) {
    return _db.userEntryDao.watchByMediaItemId(mediaItemId);
  }

  Future<UserEntry?> getByMediaItemId(String mediaItemId) {
    return _db.userEntryDao.getByMediaItemId(mediaItemId);
  }

  Future<void> updateStatus(String mediaItemId, UnifiedStatus status) async {
    final deviceId = await _getDeviceId();
    final existing = await _db.userEntryDao.getByMediaItemId(mediaItemId);
    final now = DateTime.now();

    Value<DateTime?> startedAt = const Value.absent();
    Value<DateTime?> finishedAt = const Value.absent();

    if (status == UnifiedStatus.inProgress && existing?.startedAt == null) {
      startedAt = Value(now);
    }

    if (status == UnifiedStatus.done) {
      startedAt = Value(existing?.startedAt ?? now);
      finishedAt = Value(now);
    } else if (existing?.finishedAt != null) {
      finishedAt = const Value(null);
    }

    await _db.userEntryDao.updateStatus(
      mediaItemId,
      status,
      deviceId,
      startedAt,
      finishedAt,
    );
  }

  Future<void> updateScore(String mediaItemId, int? score) async {
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.updateScore(mediaItemId, score, deviceId);
  }

  Future<void> updateNotes(String mediaItemId, String? notes) async {
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.updateNotes(mediaItemId, notes, deviceId);
  }

  Future<void> toggleFavorite(String mediaItemId, bool favorite) async {
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.toggleFavorite(mediaItemId, favorite, deviceId);
  }

  Future<String> _getDeviceId() async => '';
}

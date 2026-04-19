import '../app_database.dart';

class UserEntryRepository {
  final AppDatabase _db;

  UserEntryRepository(this._db);

  Future<void> updateStatus(String mediaItemId, UnifiedStatus status) async {
    final deviceId = await _getDeviceId();
    await _db.userEntryDao.updateStatus(mediaItemId, status, deviceId);
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

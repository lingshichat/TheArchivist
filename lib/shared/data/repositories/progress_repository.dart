import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';

class ProgressRepository {
  final AppDatabase _db;

  ProgressRepository(this._db);

  Future<void> updateProgress(
    String mediaItemId, {
    int? currentEpisode,
    int? currentPage,
    double? currentMinutes,
    double? completionRatio,
  }) async {
    final deviceId = await _getDeviceId();

    final existing = await _db.progressDao.getByMediaItemId(mediaItemId);
    if (existing == null) {
      final now = SyncStampDecorator.now();
      await _db.progressDao.upsert(ProgressEntriesCompanion.insert(
        id: DeviceIdentityService.generate(),
        mediaItemId: mediaItemId,
        currentEpisode: Value(currentEpisode),
        currentPage: Value(currentPage),
        currentMinutes: Value(currentMinutes),
        completionRatio: Value(completionRatio),
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ));
    } else {
      await _db.progressDao.updateProgress(
        mediaItemId,
        deviceId,
        currentEpisode: currentEpisode,
        currentPage: currentPage,
        currentMinutes: currentMinutes,
        completionRatio: completionRatio,
      );
    }
  }

  Future<String> _getDeviceId() async => '';
}

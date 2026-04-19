import 'package:drift/drift.dart';

import '../app_database.dart';
import '../daos/media_dao.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';

class MediaRepository {
  final AppDatabase _db;

  MediaRepository(this._db);

  // --- Home page ---

  Stream<List<MediaItemWithUserEntry>> watchContinuing({int limit = 20}) =>
      _db.mediaDao.watchContinuing(limit: limit);

  Stream<List<MediaItemWithUserEntry>> watchRecentlyAdded({int limit = 20}) =>
      _db.mediaDao.watchRecentlyAdded(limit: limit);

  Stream<List<MediaItemWithUserEntry>> watchRecentlyFinished({
    int limit = 20,
  }) =>
      _db.mediaDao.watchRecentlyFinished(limit: limit);

  // --- Library ---

  Stream<List<MediaItemWithUserEntry>> watchLibrary({
    MediaType? type,
    String? status,
    String sortBy = 'updatedAt',
    bool descending = true,
  }) =>
      _db.mediaDao.watchLibrary(
        type: type,
        status: status,
        sortBy: sortBy,
        descending: descending,
      );

  // --- Detail ---

  Stream<MediaItem> watchItem(String id) => _db.mediaDao.watchItem(id);

  // --- Write ---

  Future<String> createItem({
    required MediaType mediaType,
    required String title,
    String? subtitle,
    String? posterUrl,
    DateTime? releaseDate,
    String? overview,
    String? sourceIdsJson,
    int? runtimeMinutes,
    int? totalEpisodes,
    int? totalPages,
    double? estimatedPlayHours,
  }) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.mediaDao.upsertItem(MediaItemsCompanion.insert(
      id: id,
      mediaType: mediaType,
      title: title,
      subtitle: Value(subtitle),
      posterUrl: Value(posterUrl),
      releaseDate: Value(releaseDate),
      overview: Value(overview),
      sourceIdsJson: Value(sourceIdsJson ?? '{}'),
      runtimeMinutes: Value(runtimeMinutes),
      totalEpisodes: Value(totalEpisodes),
      totalPages: Value(totalPages),
      estimatedPlayHours: Value(estimatedPlayHours),
      createdAt: now,
      updatedAt: now,
      deviceId: Value(deviceId),
    ));

    // Create a default user entry
    await _db.userEntryDao.upsert(UserEntriesCompanion.insert(
      id: DeviceIdentityService.generate(),
      mediaItemId: id,
      createdAt: now,
      updatedAt: now,
      deviceId: Value(deviceId),
    ));

    return id;
  }

  Future<void> softDelete(String id) async {
    final deviceId = await _getDeviceId();
    await _db.mediaDao.softDelete(id, deviceId);
  }

  Future<String> _getDeviceId() async {
    // TODO: read from persisted device identity
    return '';
  }
}

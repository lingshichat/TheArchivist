import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';

class TagRepository {
  final AppDatabase _db;

  TagRepository(this._db);

  Future<String> createTag({required String name, String? color}) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.tagDao.upsert(TagsCompanion.insert(
      id: id,
      name: name,
      color: Value(color),
      createdAt: now,
      updatedAt: now,
      deviceId: Value(deviceId),
    ));

    return id;
  }

  Future<void> attachToMedia(String mediaItemId, String tagId) async {
    await _db.tagDao.attach(
      mediaItemId,
      tagId,
      DeviceIdentityService.generate(),
    );
  }

  Future<void> detachFromMedia(String mediaItemId, String tagId) async {
    await _db.tagDao.detach(mediaItemId, tagId);
  }

  Future<String> _getDeviceId() async => '';
}

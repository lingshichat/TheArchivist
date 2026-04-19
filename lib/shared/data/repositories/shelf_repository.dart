import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';

class ShelfRepository {
  final AppDatabase _db;

  ShelfRepository(this._db);

  Future<String> createShelf({
    required String name,
    ShelfKind kind = ShelfKind.user,
  }) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.shelfDao.upsert(ShelfListsCompanion.insert(
      id: id,
      name: name,
      kind: kind,
      createdAt: now,
      updatedAt: now,
      deviceId: Value(deviceId),
    ));

    return id;
  }

  Future<void> attachToMedia(String mediaItemId, String shelfListId) async {
    await _db.shelfDao.attach(
      mediaItemId,
      shelfListId,
      DeviceIdentityService.generate(),
    );
  }

  Future<void> detachFromMedia(String mediaItemId, String shelfListId) async {
    await _db.shelfDao.detach(mediaItemId, shelfListId);
  }

  Future<String> _getDeviceId() async => '';
}

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';

class ShelfRepository {
  final AppDatabase _db;

  ShelfRepository(this._db);

  Stream<List<ShelfList>> watchAll() => _db.shelfDao.watchAll();

  Stream<List<ShelfList>> watchByMediaItemId(String mediaItemId) {
    return _db.shelfDao.watchByMediaItemId(mediaItemId);
  }

  Future<List<ShelfList>> getByMediaItemId(String mediaItemId) {
    return _db.shelfDao.getByMediaItemId(mediaItemId);
  }

  Future<String> createShelf({
    required String name,
    ShelfKind kind = ShelfKind.user,
  }) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.shelfDao.upsert(
      ShelfListsCompanion.insert(
        id: id,
        name: name,
        kind: kind,
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );

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

  Future<void> syncShelvesForMedia(
    String mediaItemId,
    Iterable<String> rawNames,
  ) async {
    final desiredNames = _normalizeNames(rawNames);
    final existingShelves = await _db.shelfDao.getAll();
    final currentShelves = await _db.shelfDao.getByMediaItemId(mediaItemId);

    final existingByName = <String, ShelfList>{
      for (final shelf in existingShelves) shelf.name.toLowerCase(): shelf,
    };
    final currentIds = currentShelves.map((e) => e.id).toSet();
    final desiredIds = <String>{};

    for (final name in desiredNames) {
      final key = name.toLowerCase();
      final existing = existingByName[key];
      final shelfId = existing?.id ?? await createShelf(name: name);
      desiredIds.add(shelfId);

      if (!currentIds.contains(shelfId)) {
        await attachToMedia(mediaItemId, shelfId);
      }
    }

    for (final shelf in currentShelves) {
      if (!desiredIds.contains(shelf.id)) {
        await detachFromMedia(mediaItemId, shelf.id);
      }
    }
  }

  List<String> _normalizeNames(Iterable<String> rawNames) {
    final seen = <String>{};
    final names = <String>[];

    for (final rawName in rawNames) {
      final normalized = rawName.trim();
      if (normalized.isEmpty) {
        continue;
      }

      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        names.add(normalized);
      }
    }

    return names;
  }

  Future<String> _getDeviceId() async => '';
}

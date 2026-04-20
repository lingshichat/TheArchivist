import 'package:drift/drift.dart';

import '../app_database.dart';
import '../device_identity.dart';
import '../sync_stamp.dart';

class TagRepository {
  final AppDatabase _db;

  TagRepository(this._db);

  Stream<List<Tag>> watchAll() => _db.tagDao.watchAll();

  Stream<List<Tag>> watchByMediaItemId(String mediaItemId) {
    return _db.tagDao.watchByMediaItemId(mediaItemId);
  }

  Future<List<Tag>> getByMediaItemId(String mediaItemId) {
    return _db.tagDao.getByMediaItemId(mediaItemId);
  }

  Future<String> createTag({required String name, String? color}) async {
    final now = SyncStampDecorator.now();
    final id = DeviceIdentityService.generate();
    final deviceId = await _getDeviceId();

    await _db.tagDao.upsert(
      TagsCompanion.insert(
        id: id,
        name: name,
        color: Value(color),
        createdAt: now,
        updatedAt: now,
        deviceId: Value(deviceId),
      ),
    );

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

  Future<void> syncTagsForMedia(
    String mediaItemId,
    Iterable<String> rawNames,
  ) async {
    final desiredNames = _normalizeNames(rawNames);
    final existingTags = await _db.tagDao.getAll();
    final currentTags = await _db.tagDao.getByMediaItemId(mediaItemId);

    final existingByName = <String, Tag>{
      for (final tag in existingTags) tag.name.toLowerCase(): tag,
    };
    final currentIds = currentTags.map((e) => e.id).toSet();
    final desiredIds = <String>{};

    for (final name in desiredNames) {
      final key = name.toLowerCase();
      final existing = existingByName[key];
      final tagId = existing?.id ?? await createTag(name: name);
      desiredIds.add(tagId);

      if (!currentIds.contains(tagId)) {
        await attachToMedia(mediaItemId, tagId);
      }
    }

    for (final tag in currentTags) {
      if (!desiredIds.contains(tag.id)) {
        await detachFromMedia(mediaItemId, tag.id);
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

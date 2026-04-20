import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/shelf_repository.dart';
import 'package:record_anywhere/shared/data/repositories/tag_repository.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late TagRepository tagRepo;
  late ShelfRepository shelfRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
    tagRepo = TagRepository(db);
    shelfRepo = ShelfRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TagRepository', () {
    test('createTag persists tag', () async {
      final id = await tagRepo.createTag(name: 'Sci-Fi', color: '#FF0000');

      final tags = await db.tagDao.watchAll().first;
      expect(tags, hasLength(1));
      expect(tags.first.id, id);
      expect(tags.first.name, 'Sci-Fi');
      expect(tags.first.color, '#FF0000');
    });

    test('attachToMedia links tag to media item', () async {
      final mediaId = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Tagged Movie',
      );
      final tagId = await tagRepo.createTag(name: 'Classic');

      await tagRepo.attachToMedia(mediaId, tagId);

      final tags = await db.tagDao.watchByMediaItemId(mediaId).first;
      expect(tags, hasLength(1));
      expect(tags.first.name, 'Classic');
    });

    test('detachFromMedia removes link', () async {
      final mediaId = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Untag Movie',
      );
      final tagId = await tagRepo.createTag(name: 'Remove Me');

      await tagRepo.attachToMedia(mediaId, tagId);
      await tagRepo.detachFromMedia(mediaId, tagId);

      final tags = await db.tagDao.watchByMediaItemId(mediaId).first;
      expect(tags, isEmpty);
    });

    test('soft-deleted tags are excluded from watchAll', () async {
      await tagRepo.createTag(name: 'Active');
      final tagId = await tagRepo.createTag(name: 'Deleted');

      // Manually soft-delete via DAO
      await (db.update(db.tags)..where((t) => t.id.equals(tagId))).write(
        TagsCompanion(deletedAt: Value(DateTime.now())),
      );

      final tags = await db.tagDao.watchAll().first;
      expect(tags, hasLength(1));
      expect(tags.first.name, 'Active');
    });
  });

  group('ShelfRepository', () {
    test('createShelf persists shelf', () async {
      final id = await shelfRepo.createShelf(
        name: 'Favorites',
        kind: ShelfKind.user,
      );

      final shelves = await db.shelfDao.watchAll().first;
      expect(shelves, hasLength(1));
      expect(shelves.first.id, id);
      expect(shelves.first.name, 'Favorites');
      expect(shelves.first.kind, ShelfKind.user);
    });

    test('attachToMedia links shelf to media item', () async {
      final mediaId = await mediaRepo.createItem(
        mediaType: MediaType.book,
        title: 'Shelved Book',
      );
      final shelfId = await shelfRepo.createShelf(name: 'Reading List');

      await shelfRepo.attachToMedia(mediaId, shelfId);

      final shelves = await db.shelfDao.watchByMediaItemId(mediaId).first;
      expect(shelves, hasLength(1));
      expect(shelves.first.name, 'Reading List');
    });

    test('detachFromMedia removes link', () async {
      final mediaId = await mediaRepo.createItem(
        mediaType: MediaType.game,
        title: 'Unshelved Game',
      );
      final shelfId = await shelfRepo.createShelf(name: 'Backlog');

      await shelfRepo.attachToMedia(mediaId, shelfId);
      await shelfRepo.detachFromMedia(mediaId, shelfId);

      final shelves = await db.shelfDao.watchByMediaItemId(mediaId).first;
      expect(shelves, isEmpty);
    });
  });
}

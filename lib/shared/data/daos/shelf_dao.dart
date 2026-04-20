import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/media_item_shelves.dart';
import '../tables/shelf_lists.dart';

part 'shelf_dao.g.dart';

@DriftAccessor(tables: [ShelfLists, MediaItemShelves])
class ShelfDao extends DatabaseAccessor<AppDatabase> with _$ShelfDaoMixin {
  ShelfDao(super.db);

  Stream<List<ShelfList>> watchAll() {
    return (select(shelfLists)..where((t) => t.deletedAt.isNull())).watch();
  }

  Future<List<ShelfList>> getAll() {
    return (select(shelfLists)..where((t) => t.deletedAt.isNull())).get();
  }

  Future<void> upsert(ShelfListsCompanion shelf) {
    return into(shelfLists).insertOnConflictUpdate(shelf);
  }

  Future<void> attach(String mediaItemId, String shelfListId, String id) {
    final now = DateTime.now();
    into(mediaItemShelves).insert(
      MediaItemShelvesCompanion.insert(
        id: id,
        mediaItemId: mediaItemId,
        shelfListId: shelfListId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return Future.value();
  }

  Future<void> detach(String mediaItemId, String shelfListId) {
    return (delete(mediaItemShelves)..where(
          (t) =>
              t.mediaItemId.equals(mediaItemId) &
              t.shelfListId.equals(shelfListId),
        ))
        .go();
  }

  Stream<List<ShelfList>> watchByMediaItemId(String mediaItemId) {
    final query =
        select(shelfLists).join([
            innerJoin(
              mediaItemShelves,
              mediaItemShelves.shelfListId.equalsExp(shelfLists.id),
            ),
          ])
          ..where(mediaItemShelves.mediaItemId.equals(mediaItemId))
          ..where(shelfLists.deletedAt.isNull());

    return query.map((row) => row.readTable(shelfLists)).watch();
  }

  Future<List<ShelfList>> getByMediaItemId(String mediaItemId) {
    final query =
        select(shelfLists).join([
            innerJoin(
              mediaItemShelves,
              mediaItemShelves.shelfListId.equalsExp(shelfLists.id),
            ),
          ])
          ..where(mediaItemShelves.mediaItemId.equals(mediaItemId))
          ..where(shelfLists.deletedAt.isNull());

    return query.map((row) => row.readTable(shelfLists)).get();
  }
}

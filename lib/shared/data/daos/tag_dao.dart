import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/media_item_tags.dart';
import '../tables/tags.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, MediaItemTags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Stream<List<Tag>> watchAll() {
    return (select(tags)..where((t) => t.deletedAt.isNull())).watch();
  }

  Future<List<Tag>> getAll() {
    return (select(tags)..where((t) => t.deletedAt.isNull())).get();
  }

  Future<void> upsert(TagsCompanion tag) {
    return into(tags).insertOnConflictUpdate(tag);
  }

  Future<void> attach(String mediaItemId, String tagId, String id) {
    final now = DateTime.now();
    into(mediaItemTags).insert(
      MediaItemTagsCompanion.insert(
        id: id,
        mediaItemId: mediaItemId,
        tagId: tagId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return Future.value();
  }

  Future<void> detach(String mediaItemId, String tagId) {
    return (delete(mediaItemTags)..where(
          (t) => t.mediaItemId.equals(mediaItemId) & t.tagId.equals(tagId),
        ))
        .go();
  }

  Stream<List<Tag>> watchByMediaItemId(String mediaItemId) {
    final query =
        select(tags).join([
            innerJoin(mediaItemTags, mediaItemTags.tagId.equalsExp(tags.id)),
          ])
          ..where(mediaItemTags.mediaItemId.equals(mediaItemId))
          ..where(tags.deletedAt.isNull());

    return query.map((row) => row.readTable(tags)).watch();
  }

  Future<List<Tag>> getByMediaItemId(String mediaItemId) {
    final query =
        select(tags).join([
            innerJoin(mediaItemTags, mediaItemTags.tagId.equalsExp(tags.id)),
          ])
          ..where(mediaItemTags.mediaItemId.equals(mediaItemId))
          ..where(tags.deletedAt.isNull());

    return query.map((row) => row.readTable(tags)).get();
  }
}

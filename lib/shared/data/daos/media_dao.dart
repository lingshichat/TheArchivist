import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/media_items.dart';
import '../tables/progress_entries.dart';
import '../tables/user_entries.dart';

part 'media_dao.g.dart';

@DriftAccessor(tables: [MediaItems, UserEntries, ProgressEntries])
class MediaDao extends DatabaseAccessor<AppDatabase> with _$MediaDaoMixin {
  MediaDao(super.db);

  // --- Single item queries ---

  Stream<MediaItem> watchItem(String id) {
    return (select(mediaItems)..where((t) => t.id.equals(id))).watchSingle();
  }

  Stream<MediaItemWithUserEntry?> watchDetailBase(String id) {
    final query =
        select(mediaItems).join([
            leftOuterJoin(
              userEntries,
              userEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
            leftOuterJoin(
              progressEntries,
              progressEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
          ])
          ..where(mediaItems.id.equals(id))
          ..where(mediaItems.deletedAt.isNull())
          ..limit(1);

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return null;
      }

      return MediaItemWithUserEntry(
        mediaItem: row.readTable(mediaItems),
        userEntry: row.readTableOrNull(userEntries),
        progressEntry: row.readTableOrNull(progressEntries),
      );
    });
  }

  Future<MediaItem> getItem(String id) {
    return (select(mediaItems)..where((t) => t.id.equals(id))).getSingle();
  }

  // --- Home page queries ---

  Stream<List<MediaItemWithUserEntry>> watchContinuing({int limit = 20}) {
    final query =
        select(mediaItems).join([
            leftOuterJoin(
              userEntries,
              userEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
            leftOuterJoin(
              progressEntries,
              progressEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
          ])
          ..where(mediaItems.deletedAt.isNull())
          ..where(userEntries.status.equals('inProgress'))
          ..orderBy([OrderingTerm.desc(userEntries.updatedAt)])
          ..limit(limit);

    return query
        .map(
          (row) => MediaItemWithUserEntry(
            mediaItem: row.readTable(mediaItems),
            userEntry: row.readTableOrNull(userEntries),
            progressEntry: row.readTableOrNull(progressEntries),
          ),
        )
        .watch();
  }

  Stream<List<MediaItemWithUserEntry>> watchRecentlyAdded({int limit = 20}) {
    final query =
        select(mediaItems).join([
            leftOuterJoin(
              userEntries,
              userEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
            leftOuterJoin(
              progressEntries,
              progressEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
          ])
          ..where(mediaItems.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(mediaItems.createdAt)])
          ..limit(limit);

    return query
        .map(
          (row) => MediaItemWithUserEntry(
            mediaItem: row.readTable(mediaItems),
            userEntry: row.readTableOrNull(userEntries),
            progressEntry: row.readTableOrNull(progressEntries),
          ),
        )
        .watch();
  }

  Stream<List<MediaItemWithUserEntry>> watchRecentlyFinished({int limit = 20}) {
    final query =
        select(mediaItems).join([
            leftOuterJoin(
              userEntries,
              userEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
            leftOuterJoin(
              progressEntries,
              progressEntries.mediaItemId.equalsExp(mediaItems.id),
            ),
          ])
          ..where(mediaItems.deletedAt.isNull())
          ..where(userEntries.status.equals('done'))
          ..orderBy([OrderingTerm.desc(userEntries.finishedAt)])
          ..limit(limit);

    return query
        .map(
          (row) => MediaItemWithUserEntry(
            mediaItem: row.readTable(mediaItems),
            userEntry: row.readTableOrNull(userEntries),
            progressEntry: row.readTableOrNull(progressEntries),
          ),
        )
        .watch();
  }

  // --- Library queries ---

  Stream<List<MediaItemWithUserEntry>> watchLibrary({
    MediaType? type,
    List<MediaType>? types,
    String? status,
    String sortBy = 'updatedAt',
    bool descending = true,
  }) {
    final query = select(mediaItems).join([
      leftOuterJoin(
        userEntries,
        userEntries.mediaItemId.equalsExp(mediaItems.id),
      ),
      leftOuterJoin(
        progressEntries,
        progressEntries.mediaItemId.equalsExp(mediaItems.id),
      ),
    ]);

    var conditions = mediaItems.deletedAt.isNull();

    if (types != null && types.isNotEmpty) {
      final typeNames = types.map((e) => e.name).toList();
      conditions = conditions & mediaItems.mediaType.isIn(typeNames);
    } else if (type != null) {
      final typeStr = type.name;
      conditions = conditions & mediaItems.mediaType.equals(typeStr);
    }
    if (status != null) {
      conditions = conditions & userEntries.status.equals(status);
    }

    query.where(conditions);

    final OrderingTerm Function(Expression) orderFn;
    if (descending) {
      orderFn = (e) => OrderingTerm.desc(e);
    } else {
      orderFn = (e) => OrderingTerm.asc(e);
    }

    final Expression orderExpr;
    switch (sortBy) {
      case 'title':
        orderExpr = mediaItems.title;
        break;
      case 'score':
        orderExpr = userEntries.score;
        break;
      case 'releaseDate':
        orderExpr = mediaItems.releaseDate;
        break;
      default:
        orderExpr = mediaItems.updatedAt;
    }
    query.orderBy([orderFn(orderExpr)]);

    return query
        .map(
          (row) => MediaItemWithUserEntry(
            mediaItem: row.readTable(mediaItems),
            userEntry: row.readTableOrNull(userEntries),
            progressEntry: row.readTableOrNull(progressEntries),
          ),
        )
        .watch();
  }

  // --- Write operations ---

  Future<void> upsertItem(MediaItemsCompanion item) {
    return into(mediaItems).insertOnConflictUpdate(item);
  }

  Future<void> softDelete(String id, String deviceId) {
    final now = DateTime.now();
    return (update(mediaItems)..where((t) => t.id.equals(id))).write(
      MediaItemsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncVersion: Value.absent(),
        deviceId: Value(deviceId),
      ),
    );
  }
}

class MediaItemWithUserEntry {
  final MediaItem mediaItem;
  final UserEntry? userEntry;
  final ProgressEntry? progressEntry;

  MediaItemWithUserEntry({
    required this.mediaItem,
    this.userEntry,
    this.progressEntry,
  });
}

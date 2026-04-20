import 'package:drift/drift.dart';

import 'media_items.dart';
import 'tags.dart';

class MediaItemTags extends Table {
  TextColumn get id => text()();
  TextColumn get mediaItemId => text().references(MediaItems, #id)();
  TextColumn get tagId => text().references(Tags, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {mediaItemId, tagId},
  ];
}

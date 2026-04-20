import 'package:drift/drift.dart';

import 'media_items.dart';

class ProgressEntries extends Table {
  TextColumn get id => text()();
  TextColumn get mediaItemId => text().references(MediaItems, #id)();
  IntColumn get currentEpisode => integer().nullable()();
  IntColumn get currentPage => integer().nullable()();
  RealColumn get currentMinutes => real().nullable()();
  RealColumn get completionRatio => real().nullable()();
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
    {mediaItemId},
  ];
}

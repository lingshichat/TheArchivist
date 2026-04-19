import 'package:drift/drift.dart';

import '../converters/converters.dart';
import 'media_items.dart';

class UserEntries extends Table {
  TextColumn get id => text()();
  TextColumn get mediaItemId => text().references(MediaItems, #id)();
  TextColumn get status =>
      text().map(const StatusConverter()).withDefault(
            const Constant('wishlist'),
          )();
  IntColumn get score => integer().nullable()();
  TextColumn get review => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get favorite =>
      boolean().withDefault(const Constant(false))();
  IntColumn get reconsumeCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncVersion =>
      integer().withDefault(const Constant(0))();
  TextColumn get deviceId =>
      text().withDefault(const Constant(''))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{mediaItemId}];
}

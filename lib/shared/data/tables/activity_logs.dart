import 'package:drift/drift.dart';

import '../converters/converters.dart';
import 'media_items.dart';

class ActivityLogs extends Table {
  TextColumn get id => text()();
  TextColumn get mediaItemId => text().references(MediaItems, #id)();
  TextColumn get event => text().map(const ActivityEventConverter())();
  TextColumn get payloadJson => text().withDefault(const Constant('{}'))();
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
}

import 'package:drift/drift.dart';

class SyncQueueEntries extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get snapshotJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastAttemptedAt => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get errorSummary => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get deviceId => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

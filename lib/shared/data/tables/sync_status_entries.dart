import 'package:drift/drift.dart';

class SyncStatusEntries extends Table {
  TextColumn get id => text()();
  BoolColumn get isRunning => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastCompletedAt => dateTime().nullable()();
  TextColumn get lastErrorSummary => text().nullable()();
  IntColumn get pendingCount => integer().withDefault(const Constant(0))();
  BoolColumn get hasConflicts => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

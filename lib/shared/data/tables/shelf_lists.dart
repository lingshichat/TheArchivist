import 'package:drift/drift.dart';

enum ShelfKind { system, user }

class ShelfKindConverter extends TypeConverter<ShelfKind, String> {
  const ShelfKindConverter();

  static const _map = {ShelfKind.system: 'system', ShelfKind.user: 'user'};

  @override
  ShelfKind fromSql(String fromDb) {
    return _map.entries
        .firstWhere(
          (e) => e.value == fromDb,
          orElse: () => const MapEntry(ShelfKind.user, 'user'),
        )
        .key;
  }

  @override
  String toSql(ShelfKind value) => _map[value]!;
}

class ShelfLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text().map(const ShelfKindConverter())();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:drift/drift.dart';

import '../converters/converters.dart';

class MediaItems extends Table {
  TextColumn get id => text()();
  TextColumn get mediaType => text().map(const MediaTypeConverter())();
  TextColumn get title => text()();
  TextColumn get subtitle => text().nullable()();
  TextColumn get posterUrl => text().nullable()();
  DateTimeColumn get releaseDate => dateTime().nullable()();
  TextColumn get overview => text().nullable()();
  TextColumn get sourceIdsJson => text().withDefault(const Constant('{}'))();
  IntColumn get runtimeMinutes => integer().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  IntColumn get totalPages => integer().nullable()();
  RealColumn get estimatedPlayHours => real().nullable()();
  RealColumn get communityScore => real().nullable()();
  IntColumn get communityRatingCount => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  TextColumn get deviceId => text().withDefault(const Constant(''))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

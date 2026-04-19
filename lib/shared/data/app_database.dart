import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters/converters.dart';
import 'daos/media_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/shelf_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/user_entry_dao.dart';
import 'tables/activity_logs.dart';
import 'tables/enums.dart';
import 'tables/media_item_shelves.dart';
import 'tables/media_item_tags.dart';
import 'tables/media_items.dart';
import 'tables/progress_entries.dart';
import 'tables/shelf_lists.dart';
import 'tables/tags.dart';
import 'tables/user_entries.dart';

export 'tables/enums.dart';
export 'tables/shelf_lists.dart' show ShelfKind;

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    MediaItems,
    UserEntries,
    ProgressEntries,
    Tags,
    ShelfLists,
    MediaItemTags,
    MediaItemShelves,
    ActivityLogs,
  ],
  daos: [
    MediaDao,
    UserEntryDao,
    ProgressDao,
    TagDao,
    ShelfDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customSelect('PRAGMA foreign_keys = ON').get();
          await customSelect('PRAGMA journal_mode = WAL').get();
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'record_anywhere');
}

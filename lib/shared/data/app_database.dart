import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters/converters.dart';
import 'daos/activity_log_dao.dart';
import 'daos/media_dao.dart';
import 'daos/progress_dao.dart';
import 'daos/shelf_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/sync_status_dao.dart';
import 'daos/tag_dao.dart';
import 'daos/user_entry_dao.dart';
import 'tables/activity_logs.dart';
import 'tables/enums.dart';
import 'tables/media_item_shelves.dart';
import 'tables/media_item_tags.dart';
import 'tables/media_items.dart';
import 'tables/progress_entries.dart';
import 'tables/shelf_lists.dart';
import 'tables/sync_queue_entries.dart';
import 'tables/sync_status_entries.dart';
import 'tables/tags.dart';
import 'tables/user_entries.dart';

export 'tables/enums.dart';
export 'tables/shelf_lists.dart' show ShelfKind;
export 'tables/sync_queue_entries.dart';
export 'tables/sync_status_entries.dart';

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
    SyncQueueEntries,
    SyncStatusEntries,
  ],
  daos: [
    ActivityLogDao,
    MediaDao,
    UserEntryDao,
    ProgressDao,
    TagDao,
    ShelfDao,
    SyncQueueDao,
    SyncStatusDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createSyncConflictTable();
      await customSelect('PRAGMA foreign_keys = ON').get();
      await customSelect('PRAGMA journal_mode = WAL').get();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(syncQueueEntries);
        await m.createTable(syncStatusEntries);
      }
      if (from < 3) {
        await _createSyncConflictTable();
      }
      if (from < 4) {
        await m.addColumn(mediaItems, mediaItems.communityScore);
        await m.addColumn(mediaItems, mediaItems.communityRatingCount);
      }
    },
  );

  Future<void> _createSyncConflictTable() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS sync_conflict_entries (
        id TEXT NOT NULL PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        field_name TEXT NOT NULL,
        local_value TEXT NULL,
        remote_value TEXT NULL,
        local_updated_at TEXT NOT NULL,
        remote_updated_at TEXT NOT NULL,
        local_device_id TEXT NULL,
        remote_device_id TEXT NULL,
        detected_at TEXT NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0,
        resolved_at TEXT NULL
      )
    ''');
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'record_anywhere');
}

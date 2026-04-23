import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'device_identity.dart';
import 'repositories/activity_log_repository.dart';
import 'repositories/media_repository.dart';
import 'repositories/progress_repository.dart';
import 'repositories/shelf_repository.dart';
import 'repositories/tag_repository.dart';
import 'repositories/user_entry_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>((ref) {
  return DeviceIdentityService();
});

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(
    ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final userEntryRepositoryProvider = Provider<UserEntryRepository>((ref) {
  return UserEntryRepository(
    ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(
    ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(
    ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final shelfRepositoryProvider = Provider<ShelfRepository>((ref) {
  return ShelfRepository(
    ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepository(
    ref.watch(appDatabaseProvider),
    deviceIdentityService: ref.watch(deviceIdentityServiceProvider),
  );
});

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/add/data/bangumi_quick_add_controller.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_models.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_sync_service.dart';
import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/device_identity.dart';
import 'package:record_anywhere/shared/data/repositories/activity_log_repository.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/user_entry_repository.dart';
import 'package:record_anywhere/shared/data/source_id_map.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepository;
  late UserEntryRepository userEntryRepository;
  late ActivityLogRepository activityLogRepository;
  late DeviceIdentityService deviceIdentityService;
  late _FakeBangumiSyncService syncService;
  late BangumiQuickAddController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceIdentityService = DeviceIdentityService(
      store: InMemoryDeviceIdentityStore(deviceId: 'test-device-id'),
    );
    mediaRepository = MediaRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    userEntryRepository = UserEntryRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    activityLogRepository = ActivityLogRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    syncService = _FakeBangumiSyncService();
    controller = BangumiQuickAddController(
      mediaRepository: mediaRepository,
      userEntryRepository: userEntryRepository,
      activityLogRepository: activityLogRepository,
      bangumiSyncService: syncService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'createFromSubject writes local item, status, log and sync hook',
    () async {
      final result = await controller.createFromSubject(
        subject: const BangumiSubjectDto(
          id: 42,
          type: 2,
          name: 'Neon Genesis Evangelion',
          nameCn: '新世纪福音战士',
          summary: 'A mecha classic.',
          date: '1995-10-04',
          images: BangumiImages(common: 'https://example.com/eva.jpg'),
          eps: 26,
          totalEpisodes: 26,
        ),
        status: UnifiedStatus.inProgress,
      );

      final item = await mediaRepository.getItem(result.mediaId);
      final entry = await userEntryRepository.getByMediaItemId(result.mediaId);
      final logs = await activityLogRepository
          .watchByMediaItemId(result.mediaId)
          .first;

      expect(result.alreadyExists, isFalse);
      expect(item, isNotNull);
      expect(item!.title, 'Neon Genesis Evangelion');
      expect(item.subtitle, '新世纪福音战士');
      expect(item.posterUrl, 'https://example.com/eva.jpg');
      expect(item.totalEpisodes, 26);
      expect(SourceIdMap.get(item.sourceIdsJson, 'bangumi'), '42');
      expect(entry, isNotNull);
      expect(entry!.status, UnifiedStatus.inProgress);
      expect(entry.startedAt, isNotNull);
      expect(logs, hasLength(1));
      expect(logs.single.event, ActivityEvent.added);
      expect(syncService.calls, hasLength(1));
      expect(syncService.calls.single.mediaItemId, result.mediaId);
      expect(syncService.calls.single.status, UnifiedStatus.inProgress);
    },
  );

  test(
    'createFromSubject is idempotent for existing bangumi source id',
    () async {
      final existingId = await mediaRepository.createItem(
        mediaType: MediaType.book,
        title: 'Existing Item',
        sourceIdsJson: SourceIdMap.encode(const <String, String>{
          'bangumi': '7',
        }),
      );

      final result = await controller.createFromSubject(
        subject: const BangumiSubjectDto(id: 7, type: 1, name: 'Book Title'),
        status: UnifiedStatus.wishlist,
      );

      final items = await (db.select(
        db.mediaItems,
      )..where((t) => t.deletedAt.isNull())).get();

      expect(result.alreadyExists, isTrue);
      expect(result.mediaId, existingId);
      expect(items, hasLength(1));
      expect(syncService.calls, isEmpty);
    },
  );
}

class _FakeBangumiSyncService implements BangumiSyncService {
  final List<_SyncCall> calls = <_SyncCall>[];

  @override
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  }) async {
    calls.add(
      _SyncCall(mediaItemId: mediaItemId, status: status, score: score),
    );
  }
}

class _SyncCall {
  const _SyncCall({
    required this.mediaItemId,
    required this.status,
    required this.score,
  });

  final String mediaItemId;
  final UnifiedStatus? status;
  final int? score;
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_api_service.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_models.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_pull_service.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_sync_status.dart';
import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/device_identity.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/user_entry_repository.dart';
import 'package:record_anywhere/shared/data/source_id_map.dart';
import 'package:record_anywhere/shared/network/bangumi_api_client.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepository;
  late UserEntryRepository userEntryRepository;
  late DeviceIdentityService deviceIdentityService;

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
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'pullCollections imports remote-only rows via subject fallback',
    () async {
    final service = BangumiCollectionPullService(
      apiService: _FakeBangumiApiService(
        pagesBySubjectType: <int, List<List<BangumiCollectionDto>>>{
          2: <List<BangumiCollectionDto>>[
            <BangumiCollectionDto>[
              const BangumiCollectionDto(subjectId: 42, type: 2, rate: 7),
            ],
          ],
        },
        subjects: <int, BangumiSubjectDto>{
          42: const BangumiSubjectDto(
            id: 42,
              type: 2,
              name: 'Neon Genesis Evangelion',
              nameCn: '新世纪福音战士',
              summary: 'test summary',
              date: '1995-10-04',
            ),
          },
        ),
        mediaRepository: mediaRepository,
        userEntryRepository: userEntryRepository,
      );

      final summary = await service.pullCollections(
        username: 'ikari',
        trigger: BangumiSyncTrigger.postConnect,
      );

      final imported = await mediaRepository.findBySourceId('bangumi', '42');
      final entry = await userEntryRepository.getByMediaItemId(imported!.id);

      expect(summary.importedCount, 1);
      expect(summary.updatedCount, 0);
      expect(imported.title, 'Neon Genesis Evangelion');
      expect(SourceIdMap.get(imported.sourceIdsJson, 'bangumi'), '42');
      expect(entry?.status, UnifiedStatus.inProgress);
      expect(entry?.score, 7);
      expect(entry?.lastSyncedAt, isNotNull);
    },
  );

  test(
    'pullCollections updates a clean local row and marks it synced',
    () async {
    final service = BangumiCollectionPullService(
      apiService: _FakeBangumiApiService(
        pagesBySubjectType: <int, List<List<BangumiCollectionDto>>>{
          6: <List<BangumiCollectionDto>>[
            <BangumiCollectionDto>[
              const BangumiCollectionDto(subjectId: 9, type: 3, rate: 8),
            ],
          ],
        },
      ),
      mediaRepository: mediaRepository,
      userEntryRepository: userEntryRepository,
        now: () => DateTime(2026, 4, 21, 12, 30),
      );

      final mediaId = await mediaRepository.createItem(
        mediaType: MediaType.movie,
        title: 'Arrival',
        sourceIdsJson: SourceIdMap.encode(const <String, String>{
          'bangumi': '9',
        }),
      );

      final summary = await service.pullCollections(
        username: 'ikari',
        trigger: BangumiSyncTrigger.manual,
      );

      final mediaItem = await mediaRepository.getItem(mediaId);
      final entry = await userEntryRepository.getByMediaItemId(mediaId);

      expect(summary.updatedCount, 1);
      expect(summary.localWinsCount, 0);
      expect(entry?.status, UnifiedStatus.done);
      expect(entry?.score, 8);
      expect(entry?.lastSyncedAt, DateTime(2026, 4, 21, 12, 30));
      expect(mediaItem?.lastSyncedAt, DateTime(2026, 4, 21, 12, 30));
    },
  );

  test('pullCollections keeps local dirty rows and counts localWins', () async {
    final service = BangumiCollectionPullService(
      apiService: _FakeBangumiApiService(
        pagesBySubjectType: <int, List<List<BangumiCollectionDto>>>{
          2: <List<BangumiCollectionDto>>[
            <BangumiCollectionDto>[
              const BangumiCollectionDto(subjectId: 7, type: 3, rate: 9),
            ],
          ],
        },
      ),
      mediaRepository: mediaRepository,
      userEntryRepository: userEntryRepository,
    );

    final mediaId = await mediaRepository.createItem(
      mediaType: MediaType.tv,
      title: 'Dirty Local Show',
      sourceIdsJson: SourceIdMap.encode(const <String, String>{'bangumi': '7'}),
    );
    await userEntryRepository.updateStatus(mediaId, UnifiedStatus.inProgress);

    final summary = await service.pullCollections(
      username: 'ikari',
      trigger: BangumiSyncTrigger.startupRestore,
    );

    final entry = await userEntryRepository.getByMediaItemId(mediaId);

    expect(summary.localWinsCount, 1);
    expect(summary.updatedCount, 0);
    expect(entry?.status, UnifiedStatus.inProgress);
    expect(entry?.score, isNull);
    expect(entry?.lastSyncedAt, isNull);
  });
}

class _FakeBangumiApiService extends BangumiApiService {
  _FakeBangumiApiService({
    required this.pagesBySubjectType,
    this.subjects = const <int, BangumiSubjectDto>{},
  }) : super(BangumiApiClient(userAgent: 'test-agent'));

  final Map<int, List<List<BangumiCollectionDto>>> pagesBySubjectType;
  final Map<int, BangumiSubjectDto> subjects;
  final Map<int, int> _subjectTypeOffsets = <int, int>{};

  @override
  Future<BangumiCollectionPage> listCollections(
    String username, {
    int limit = 30,
    int offset = 0,
    int? subjectType,
  }) async {
    final normalizedSubjectType = subjectType ?? -1;
    final pages = pagesBySubjectType[normalizedSubjectType] ?? const <List<BangumiCollectionDto>>[];
    final pageIndex = _subjectTypeOffsets[normalizedSubjectType] ?? 0;
    _subjectTypeOffsets[normalizedSubjectType] = pageIndex + 1;
    if (pageIndex >= pages.length) {
      return const BangumiCollectionPage(
        total: 0,
        data: <BangumiCollectionDto>[],
        limit: 30,
        offset: 0,
      );
    }

    final data = pages[pageIndex];
    final total = pages.fold<int>(
      0,
      (count, page) => count + page.length,
    );
    return BangumiCollectionPage(
      total: total,
      data: data,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<BangumiSubjectDto> getSubject(int id) async {
    final subject = subjects[id];
    if (subject == null) {
      throw const BangumiNotFoundError('subject not found');
    }
    return subject;
  }
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_progress_sync_service.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_sync_service.dart';

import 'package:record_anywhere/features/add/data/add_entry_controller.dart';
import 'package:record_anywhere/features/detail/data/detail_actions_controller.dart';
import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/device_identity.dart';
import 'package:record_anywhere/shared/data/repositories/activity_log_repository.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/progress_repository.dart';
import 'package:record_anywhere/shared/data/repositories/shelf_repository.dart';
import 'package:record_anywhere/shared/data/repositories/tag_repository.dart';
import 'package:record_anywhere/shared/data/repositories/user_entry_repository.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late UserEntryRepository userEntryRepo;
  late ProgressRepository progressRepo;
  late TagRepository tagRepo;
  late ShelfRepository shelfRepo;
  late ActivityLogRepository activityLogRepo;
  late DeviceIdentityService deviceIdentityService;
  late _FakeBangumiSyncService bangumiSyncService;
  late AddEntryController addEntryController;
  late DetailActionsController detailActionsController;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deviceIdentityService = DeviceIdentityService(
      store: InMemoryDeviceIdentityStore(deviceId: 'test-device-id'),
    );
    mediaRepo = MediaRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    userEntryRepo = UserEntryRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    progressRepo = ProgressRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    tagRepo = TagRepository(db, deviceIdentityService: deviceIdentityService);
    shelfRepo = ShelfRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    activityLogRepo = ActivityLogRepository(
      db,
      deviceIdentityService: deviceIdentityService,
    );
    bangumiSyncService = _FakeBangumiSyncService();
    final bangumiProgressSyncService = _FakeBangumiProgressSyncService();
    addEntryController = AddEntryController(
      mediaRepository: mediaRepo,
      tagRepository: tagRepo,
      shelfRepository: shelfRepo,
      activityLogRepository: activityLogRepo,
    );
    detailActionsController = DetailActionsController(
      mediaRepository: mediaRepo,
      userEntryRepository: userEntryRepo,
      progressRepository: progressRepo,
      tagRepository: tagRepo,
      shelfRepository: shelfRepo,
      activityLogRepository: activityLogRepo,
      bangumiSyncService: bangumiSyncService,
      bangumiProgressSyncService: bangumiProgressSyncService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('MediaRepository', () {
    test('createItem inserts media item and default user entry', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Test Movie',
        subtitle: 'A subtitle',
      );

      final item = await db.mediaDao.getItem(id);
      expect(item.title, 'Test Movie');
      expect(item.mediaType, MediaType.movie);
      expect(item.deletedAt, isNull);

      final entry = await db.userEntryDao.getByMediaItemId(id);
      expect(entry, isNotNull);
      expect(entry!.status, UnifiedStatus.wishlist);
      expect(item.deviceId, 'test-device-id');
      expect(entry.deviceId, 'test-device-id');
    });

    test('softDelete hides item from queries', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.book,
        title: 'Test Book',
      );

      await mediaRepo.softDelete(id);

      final items = await db.mediaDao.watchLibrary().first;
      expect(items, isEmpty);
    });

    test('watchContinuing returns only inProgress items', () async {
      final id1 = await mediaRepo.createItem(
        mediaType: MediaType.tv,
        title: 'Show A',
      );
      final id2 = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Movie B',
      );

      await userEntryRepo.updateStatus(id1, UnifiedStatus.inProgress);
      await userEntryRepo.updateStatus(id2, UnifiedStatus.done);

      final continuing = await mediaRepo.watchContinuing().first;
      expect(continuing, hasLength(1));
      expect(continuing.first.mediaItem.title, 'Show A');
    });

    test(
      'watchRecentlyAdded returns items ordered by createdAt desc',
      () async {
        await mediaRepo.createItem(mediaType: MediaType.movie, title: 'First');
        await Future<void>.delayed(const Duration(seconds: 1));
        await mediaRepo.createItem(mediaType: MediaType.movie, title: 'Second');

        final recent = await mediaRepo.watchRecentlyAdded().first;
        expect(recent, hasLength(2));
        expect(recent.first.mediaItem.title, 'Second');
      },
    );

    test(
      'watchRecentlyFinished returns done items ordered by finishedAt',
      () async {
        final id1 = await mediaRepo.createItem(
          mediaType: MediaType.movie,
          title: 'Finished A',
        );
        final id2 = await mediaRepo.createItem(
          mediaType: MediaType.book,
          title: 'Finished B',
        );

        await userEntryRepo.updateStatus(id1, UnifiedStatus.done);
        await userEntryRepo.updateStatus(id2, UnifiedStatus.done);

        final finished = await mediaRepo.watchRecentlyFinished().first;
        expect(finished, hasLength(2));
      },
    );

    test('watchLibrary filters by mediaType', () async {
      await mediaRepo.createItem(mediaType: MediaType.movie, title: 'Movie');
      await mediaRepo.createItem(mediaType: MediaType.book, title: 'Book');
      await mediaRepo.createItem(mediaType: MediaType.game, title: 'Game');

      final movies = await mediaRepo.watchLibrary(type: MediaType.movie).first;
      expect(movies, hasLength(1));
      expect(movies.first.mediaItem.title, 'Movie');
    });

    test('watchLibrary filters by status', () async {
      final id1 = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'In Progress',
      );
      await mediaRepo.createItem(mediaType: MediaType.movie, title: 'Wishlist');

      await userEntryRepo.updateStatus(id1, UnifiedStatus.inProgress);

      final inProgress = await mediaRepo
          .watchLibrary(status: 'inProgress')
          .first;
      expect(inProgress, hasLength(1));
      expect(inProgress.first.mediaItem.title, 'In Progress');
    });
  });

  group('UserEntryRepository', () {
    test('updateScore persists score', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Scored Movie',
      );

      await userEntryRepo.updateScore(id, 8);

      final entry = await db.userEntryDao.getByMediaItemId(id);
      expect(entry!.score, 8);
    });

    test('updateNotes persists notes', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Noted Movie',
      );

      await userEntryRepo.updateNotes(id, 'Great film');

      final entry = await db.userEntryDao.getByMediaItemId(id);
      expect(entry!.notes, 'Great film');
    });

    test('toggleFavorite persists favorite', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Fav Movie',
      );

      await userEntryRepo.toggleFavorite(id, true);

      final entry = await db.userEntryDao.getByMediaItemId(id);
      expect(entry!.favorite, true);
    });

    test('status change refreshes updatedAt', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Timestamp Movie',
      );

      final before = await db.userEntryDao.getByMediaItemId(id);
      // SQLite dateTime precision is second-level
      await Future<void>.delayed(const Duration(seconds: 1));

      await userEntryRepo.updateStatus(id, UnifiedStatus.inProgress);

      final after = await db.userEntryDao.getByMediaItemId(id);
      expect(
        after!.updatedAt.millisecondsSinceEpoch,
        greaterThan(before!.updatedAt.millisecondsSinceEpoch),
      );
    });

    test(
      'status change maintains startedAt and finishedAt semantics',
      () async {
        final id = await mediaRepo.createItem(
          mediaType: MediaType.movie,
          title: 'Lifecycle Movie',
        );

        await userEntryRepo.updateStatus(id, UnifiedStatus.inProgress);
        final started = await db.userEntryDao.getByMediaItemId(id);

        expect(started!.startedAt, isNotNull);
        expect(started.finishedAt, isNull);

        await userEntryRepo.updateStatus(id, UnifiedStatus.done);
        final finished = await db.userEntryDao.getByMediaItemId(id);

        expect(finished!.startedAt, isNotNull);
        expect(finished.finishedAt, isNotNull);

        await userEntryRepo.updateStatus(id, UnifiedStatus.onHold);
        final reopened = await db.userEntryDao.getByMediaItemId(id);

        expect(reopened!.startedAt, isNotNull);
        expect(reopened.finishedAt, isNull);
      },
    );
  });

  group('ProgressRepository', () {
    test('updateProgress creates new entry when none exists', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.tv,
        title: 'Progress Show',
      );

      await progressRepo.updateProgress(
        id,
        currentEpisode: 5,
        completionRatio: 0.5,
      );

      final progress = await db.progressDao.getByMediaItemId(id);
      expect(progress, isNotNull);
      expect(progress!.currentEpisode, 5);
      expect(progress.completionRatio, 0.5);
    });

    test('updateProgress updates existing entry', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.book,
        title: 'Progress Book',
      );

      await progressRepo.updateProgress(id, currentPage: 50);
      await progressRepo.updateProgress(id, currentPage: 100);

      final progress = await db.progressDao.getByMediaItemId(id);
      expect(progress!.currentPage, 100);
      expect(progress.deviceId, 'test-device-id');
    });

    test('applyRemoteProgress writes synced progress state', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.tv,
        title: 'Remote Progress Show',
      );

      await progressRepo.applyRemoteProgress(
        id,
        currentEpisode: 12,
        completionRatio: 0.8,
        syncedAt: DateTime(2026, 4, 22, 10, 0),
      );

      final progress = await db.progressDao.getByMediaItemId(id);
      expect(progress, isNotNull);
      expect(progress!.currentEpisode, 12);
      expect(progress.completionRatio, 0.8);
      expect(progress.lastSyncedAt, DateTime(2026, 4, 22, 10, 0));
      expect(progress.deviceId, 'test-device-id');
    });
  });

  group('ActivityLogRepository', () {
    test('appendEvent persists and exposes logs by media item', () async {
      final id = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Logged Movie',
      );

      await activityLogRepo.appendEvent(
        id,
        ActivityEvent.scoreChanged,
        payload: const <String, Object?>{'score': 9},
      );

      final logs = await activityLogRepo.watchByMediaItemId(id).first;
      expect(logs, hasLength(1));
      expect(logs.first.event, ActivityEvent.scoreChanged);
      expect(logs.first.payloadJson, contains('"score":9'));
    });
  });

  group('local record flow', () {
    test('empty archive can create update and soft-delete an entry', () async {
      expect(await mediaRepo.watchLibrary().first, isEmpty);

      final mediaId = await addEntryController.create(
        const AddEntryInput(
          mediaType: MediaType.movie,
          title: 'Flow Movie',
          subtitle: 'Local only',
          overview: 'A local-first archive test.',
          runtimeMinutes: 150,
          tags: <String>['Noir', 'Classic'],
          shelves: <String>['Weekend'],
        ),
      );

      final libraryAfterCreate = await mediaRepo.watchLibrary().first;
      expect(libraryAfterCreate, hasLength(1));
      expect(libraryAfterCreate.first.mediaItem.id, mediaId);

      final createTags = await tagRepo.getByMediaItemId(mediaId);
      final createShelves = await shelfRepo.getByMediaItemId(mediaId);
      final createLogs = await activityLogRepo
          .watchByMediaItemId(mediaId)
          .first;

      expect(createTags.map((e) => e.name), containsAll(['Noir', 'Classic']));
      expect(createShelves.map((e) => e.name), contains('Weekend'));
      expect(createLogs.first.event, ActivityEvent.added);

      await detailActionsController.saveChanges(
        mediaId,
        const DetailEntryUpdateInput(
          mediaType: MediaType.movie,
          status: UnifiedStatus.inProgress,
          score: 8,
          progressValue: 124,
          notes: 'Watched the first act locally.',
          tags: <String>['Noir', 'Favorite'],
          shelves: <String>['Weekend', 'Top Picks'],
        ),
      );

      final entry = await userEntryRepo.getByMediaItemId(mediaId);
      final progress = await progressRepo.getByMediaItemId(mediaId);
      final updatedTags = await tagRepo.getByMediaItemId(mediaId);
      final updatedShelves = await shelfRepo.getByMediaItemId(mediaId);
      final updatedLogs = await activityLogRepo
          .watchByMediaItemId(mediaId)
          .first;

      expect(entry!.status, UnifiedStatus.inProgress);
      expect(entry.score, 8);
      expect(entry.notes, 'Watched the first act locally.');
      expect(entry.startedAt, isNotNull);
      expect(progress!.currentMinutes, 124);
      expect(updatedTags.map((e) => e.name), containsAll(['Noir', 'Favorite']));
      expect(
        updatedShelves.map((e) => e.name),
        containsAll(['Weekend', 'Top Picks']),
      );
      expect(
        updatedLogs.map((e) => e.event),
        containsAll(<ActivityEvent>[
          ActivityEvent.added,
          ActivityEvent.statusChanged,
          ActivityEvent.scoreChanged,
          ActivityEvent.progressChanged,
          ActivityEvent.noteEdited,
        ]),
      );

      await detailActionsController.delete(mediaId);

      final libraryAfterDelete = await mediaRepo.watchLibrary().first;
      final deletedItem = await db.mediaDao.getItem(mediaId);

      expect(libraryAfterDelete, isEmpty);
      expect(deletedItem.deletedAt, isNotNull);
    });
  });

  group('Bangumi sync hook', () {
    test('quick status change triggers one Bangumi push', () async {
      final mediaId = await mediaRepo.createItem(
        mediaType: MediaType.tv,
        title: 'Synced Show',
        sourceIdsJson: '{"bangumi":"42"}',
      );

      await detailActionsController.applyQuickStatus(
        mediaId,
        UnifiedStatus.inProgress,
      );

      expect(bangumiSyncService.calls, hasLength(1));
      expect(bangumiSyncService.calls.single.mediaItemId, mediaId);
      expect(bangumiSyncService.calls.single.status, UnifiedStatus.inProgress);
      expect(bangumiSyncService.calls.single.score, isNull);
    });

    test('saveChanges pushes once when both status and score change', () async {
      final mediaId = await mediaRepo.createItem(
        mediaType: MediaType.movie,
        title: 'Synced Movie',
        sourceIdsJson: '{"bangumi":"7"}',
      );

      await detailActionsController.saveChanges(
        mediaId,
        const DetailEntryUpdateInput(
          mediaType: MediaType.movie,
          status: UnifiedStatus.done,
          score: 9,
          progressValue: null,
          notes: null,
          tags: <String>[],
          shelves: <String>[],
        ),
      );

      expect(bangumiSyncService.calls, hasLength(1));
      expect(bangumiSyncService.calls.single.mediaItemId, mediaId);
      expect(bangumiSyncService.calls.single.status, UnifiedStatus.done);
      expect(bangumiSyncService.calls.single.score, 9);
    });

    test(
      'saveChanges pushes score-only update when status stays the same',
      () async {
        final mediaId = await mediaRepo.createItem(
          mediaType: MediaType.movie,
          title: 'Scored Sync Movie',
          sourceIdsJson: '{"bangumi":"9"}',
        );

        await detailActionsController.saveChanges(
          mediaId,
          const DetailEntryUpdateInput(
            mediaType: MediaType.movie,
            status: UnifiedStatus.wishlist,
            score: 8,
            progressValue: null,
            notes: null,
            tags: <String>[],
            shelves: <String>[],
          ),
        );

        expect(bangumiSyncService.calls, hasLength(1));
        expect(bangumiSyncService.calls.single.mediaItemId, mediaId);
        expect(bangumiSyncService.calls.single.status, isNull);
        expect(bangumiSyncService.calls.single.score, 8);
      },
    );
  });
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

class _FakeBangumiProgressSyncService implements BangumiProgressSyncService {
  final List<String> pushedMediaItemIds = <String>[];

  @override
  Future<void> pushProgress({required String mediaItemId}) async {
    pushedMediaItemIds.add(mediaItemId);
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

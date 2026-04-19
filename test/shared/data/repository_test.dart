import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/progress_repository.dart';
import 'package:record_anywhere/shared/data/repositories/user_entry_repository.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepo;
  late UserEntryRepository userEntryRepo;
  late ProgressRepository progressRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mediaRepo = MediaRepository(db);
    userEntryRepo = UserEntryRepository(db);
    progressRepo = ProgressRepository(db);
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

    test('watchRecentlyAdded returns items ordered by createdAt desc',
        () async {
      await mediaRepo.createItem(mediaType: MediaType.movie, title: 'First');
      await Future<void>.delayed(const Duration(seconds: 1));
      await mediaRepo.createItem(mediaType: MediaType.movie, title: 'Second');

      final recent = await mediaRepo.watchRecentlyAdded().first;
      expect(recent, hasLength(2));
      expect(recent.first.mediaItem.title, 'Second');
    });

    test('watchRecentlyFinished returns done items ordered by finishedAt',
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
    });

    test('watchLibrary filters by mediaType', () async {
      await mediaRepo.createItem(mediaType: MediaType.movie, title: 'Movie');
      await mediaRepo.createItem(mediaType: MediaType.book, title: 'Book');
      await mediaRepo.createItem(mediaType: MediaType.game, title: 'Game');

      final movies = await mediaRepo
          .watchLibrary(type: MediaType.movie)
          .first;
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
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_api_service.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_sync_feedback.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_sync_service.dart';
import 'package:record_anywhere/features/bangumi/data/providers.dart';
import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/data/repositories/media_repository.dart';
import 'package:record_anywhere/shared/data/repositories/user_entry_repository.dart';
import 'package:record_anywhere/shared/data/source_id_map.dart';
import 'package:record_anywhere/shared/network/bangumi_api_client.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_token_store.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepository;
  late UserEntryRepository userEntryRepository;
  late ProviderContainer container;
  late BangumiSyncFeedbackController feedbackController;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mediaRepository = MediaRepository(db);
    userEntryRepository = UserEntryRepository(db);
    container = ProviderContainer();
    feedbackController = container.read(bangumiSyncFeedbackProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('pushCollection skips silently when user is not bound', () async {
    final service = BangumiCollectionSyncService(
      apiService: _FakeBangumiApiService(),
      mediaRepository: mediaRepository,
      userEntryRepository: userEntryRepository,
      tokenStore: InMemoryBangumiTokenStore(),
      feedbackController: feedbackController,
      onUnauthorized: () async {},
    );

    final mediaId = await mediaRepository.createItem(
      mediaType: MediaType.tv,
      title: 'Unbound Show',
      sourceIdsJson: SourceIdMap.encode(const <String, String>{
        'bangumi': '42',
      }),
    );

    await service.pushCollection(
      mediaItemId: mediaId,
      status: UnifiedStatus.inProgress,
    );

    expect(container.read(bangumiSyncFeedbackProvider), isNull);
  });

  test(
    'pushCollection skips silently when item has no bangumi source id',
    () async {
      final apiService = _FakeBangumiApiService();
      final service = BangumiCollectionSyncService(
        apiService: apiService,
        mediaRepository: mediaRepository,
        userEntryRepository: userEntryRepository,
        tokenStore: InMemoryBangumiTokenStore(token: 'bound-token'),
        feedbackController: feedbackController,
        onUnauthorized: () async {},
      );

      final mediaId = await mediaRepository.createItem(
        mediaType: MediaType.tv,
        title: 'Local Only Show',
      );

      await service.pushCollection(
        mediaItemId: mediaId,
        status: UnifiedStatus.inProgress,
      );

      expect(apiService.updateCalls, isEmpty);
      expect(apiService.patchCalls, isEmpty);
      expect(container.read(bangumiSyncFeedbackProvider), isNull);
    },
  );

  test(
    'pushCollection uses updateCollection for status sync and publishes success',
    () async {
      final apiService = _FakeBangumiApiService();
      final service = BangumiCollectionSyncService(
        apiService: apiService,
        mediaRepository: mediaRepository,
        userEntryRepository: userEntryRepository,
        tokenStore: InMemoryBangumiTokenStore(token: 'bound-token'),
        feedbackController: feedbackController,
        onUnauthorized: () async {},
      );

      final mediaId = await mediaRepository.createItem(
        mediaType: MediaType.tv,
        title: 'Synced Show',
        sourceIdsJson: SourceIdMap.encode(const <String, String>{
          'bangumi': '42',
        }),
      );

      await service.pushCollection(
        mediaItemId: mediaId,
        status: UnifiedStatus.done,
        score: 8,
      );

      expect(apiService.updateCalls, hasLength(1));
      expect(apiService.updateCalls.single.subjectId, 42);
      expect(apiService.updateCalls.single.type, 3);
      expect(apiService.updateCalls.single.rate, 8);

      final feedback = container.read(bangumiSyncFeedbackProvider);
      expect(feedback, isNotNull);
      expect(feedback!.message, 'Synced to Bangumi.');
      expect(feedback.isError, isFalse);

      final mediaItem = await mediaRepository.getItem(mediaId);
      final entry = await userEntryRepository.getByMediaItemId(mediaId);
      expect(mediaItem?.lastSyncedAt, isNotNull);
      expect(entry?.lastSyncedAt, isNotNull);
    },
  );

  test('pushCollection uses patchCollection for score-only sync', () async {
    final apiService = _FakeBangumiApiService();
    final service = BangumiCollectionSyncService(
      apiService: apiService,
      mediaRepository: mediaRepository,
      userEntryRepository: userEntryRepository,
      tokenStore: InMemoryBangumiTokenStore(token: 'bound-token'),
      feedbackController: feedbackController,
      onUnauthorized: () async {},
    );

    final mediaId = await mediaRepository.createItem(
      mediaType: MediaType.movie,
      title: 'Scored Movie',
      sourceIdsJson: SourceIdMap.encode(const <String, String>{'bangumi': '9'}),
    );

    await service.pushCollection(mediaItemId: mediaId, score: 10);

    expect(apiService.updateCalls, isEmpty);
    expect(apiService.patchCalls, hasLength(1));
    expect(apiService.patchCalls.single.subjectId, 9);
    expect(apiService.patchCalls.single.body['rate'], 10);
  });

  test(
    'pushCollection clears auth on unauthorized and publishes failure',
    () async {
      var unauthorizedTriggered = false;
      final service = BangumiCollectionSyncService(
        apiService: _FakeBangumiApiService(
          updateError: const BangumiUnauthorizedError('expired'),
        ),
        mediaRepository: mediaRepository,
        userEntryRepository: userEntryRepository,
        tokenStore: InMemoryBangumiTokenStore(token: 'expired-token'),
        feedbackController: feedbackController,
        onUnauthorized: () async {
          unauthorizedTriggered = true;
        },
      );

      final mediaId = await mediaRepository.createItem(
        mediaType: MediaType.tv,
        title: 'Expired Show',
        sourceIdsJson: SourceIdMap.encode(const <String, String>{
          'bangumi': '5',
        }),
      );

      await service.pushCollection(
        mediaItemId: mediaId,
        status: UnifiedStatus.inProgress,
      );

      expect(unauthorizedTriggered, isTrue);
      final feedback = container.read(bangumiSyncFeedbackProvider);
      expect(feedback, isNotNull);
      expect(
        feedback!.message,
        'Bangumi connection expired. Reconnect in Settings.',
      );
      expect(feedback.isError, isTrue);
    },
  );
}

class _FakeBangumiApiService extends BangumiApiService {
  _FakeBangumiApiService({this.updateError})
    : super(BangumiApiClient(userAgent: 'test-agent'));

  final Object? updateError;
  final List<_UpdateCall> updateCalls = <_UpdateCall>[];
  final List<_PatchCall> patchCalls = <_PatchCall>[];

  @override
  Future<void> updateCollection(
    int subjectId, {
    required int type,
    int? rate,
    String? comment,
    bool? isPrivate,
    List<String>? tags,
  }) async {
    if (updateError != null) {
      throw updateError!;
    }

    updateCalls.add(_UpdateCall(subjectId: subjectId, type: type, rate: rate));
  }

  @override
  Future<void> patchCollection(int subjectId, Map<String, Object?> body) async {
    patchCalls.add(_PatchCall(subjectId: subjectId, body: body));
  }
}

class _UpdateCall {
  const _UpdateCall({
    required this.subjectId,
    required this.type,
    required this.rate,
  });

  final int subjectId;
  final int type;
  final int? rate;
}

class _PatchCall {
  const _PatchCall({required this.subjectId, required this.body});

  final int subjectId;
  final Map<String, Object?> body;
}

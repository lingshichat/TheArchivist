import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/add/data/bangumi_search_providers.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_api_service.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_models.dart';
import 'package:record_anywhere/features/bangumi/data/providers.dart';
import 'package:record_anywhere/shared/network/bangumi_api_client.dart';

void main() {
  test(
    'bangumi search provider appends pages while keeping loaded items',
    () async {
      final fakeService = _FakeBangumiApiService(
        List<BangumiSubjectDto>.generate(45, (index) {
          return BangumiSubjectDto(
            id: index + 1,
            type: 2,
            name: 'Subject ${index + 1}',
          );
        }),
      );

      final container = ProviderContainer(
        overrides: [bangumiApiServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      const request = BangumiSearchRequest(
        keyword: 'eva',
        filter: BangumiSearchFilter.animation,
      );

      final initial = await container.read(
        bangumiSearchProvider(request).future,
      );
      expect(initial.items, hasLength(20));
      expect(initial.total, 45);
      expect(initial.hasMore, isTrue);
      expect(fakeService.calls, hasLength(1));
      expect(fakeService.calls.single.offset, 0);

      await container.read(bangumiSearchProvider(request).notifier).loadMore();
      final secondPage = container
          .read(bangumiSearchProvider(request))
          .valueOrNull;
      expect(secondPage, isNotNull);
      expect(secondPage!.items, hasLength(40));
      expect(secondPage.hasMore, isTrue);
      expect(fakeService.calls, hasLength(2));
      expect(fakeService.calls[1].offset, 20);

      await container.read(bangumiSearchProvider(request).notifier).loadMore();
      final finalPage = container
          .read(bangumiSearchProvider(request))
          .valueOrNull;
      expect(finalPage, isNotNull);
      expect(finalPage!.items, hasLength(45));
      expect(finalPage.hasMore, isFalse);
      expect(fakeService.calls, hasLength(3));
      expect(fakeService.calls[2].offset, 40);

      await container.read(bangumiSearchProvider(request).notifier).loadMore();
      expect(fakeService.calls, hasLength(3));
    },
  );
}

class _FakeBangumiApiService extends BangumiApiService {
  _FakeBangumiApiService(this.dataset)
    : super(BangumiApiClient(userAgent: 'test-agent'));

  final List<BangumiSubjectDto> dataset;
  final List<_SearchCall> calls = <_SearchCall>[];

  @override
  Future<BangumiSearchResult> searchSubjects(
    String keyword, {
    Map<String, Object?>? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    calls.add(_SearchCall(keyword: keyword, limit: limit, offset: offset));

    return BangumiSearchResult(
      total: dataset.length,
      data: dataset.skip(offset).take(limit).toList(growable: false),
      limit: limit,
      offset: offset,
    );
  }
}

class _SearchCall {
  const _SearchCall({
    required this.keyword,
    required this.limit,
    required this.offset,
  });

  final String keyword;
  final int limit;
  final int offset;
}

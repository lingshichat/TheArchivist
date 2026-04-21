import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/bangumi/data/bangumi_models.dart';
import '../../../features/bangumi/data/providers.dart';
import '../../../shared/data/app_database.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/data/source_id_map.dart';
import '../../../shared/utils/step_logger.dart';

enum BangumiSearchFilter { all, book, animation, game, liveAction }

extension BangumiSearchFilterX on BangumiSearchFilter {
  String get label {
    switch (this) {
      case BangumiSearchFilter.all:
        return 'All';
      case BangumiSearchFilter.book:
        return 'Book';
      case BangumiSearchFilter.animation:
        return 'Animation';
      case BangumiSearchFilter.game:
        return 'Game';
      case BangumiSearchFilter.liveAction:
        return 'Live Action';
    }
  }

  List<int> get bangumiTypes {
    switch (this) {
      case BangumiSearchFilter.all:
        return const <int>[1, 2, 4, 6];
      case BangumiSearchFilter.book:
        return const <int>[1];
      case BangumiSearchFilter.animation:
        return const <int>[2];
      case BangumiSearchFilter.game:
        return const <int>[4];
      case BangumiSearchFilter.liveAction:
        return const <int>[6];
    }
  }
}

class BangumiSearchRequest {
  const BangumiSearchRequest({required this.keyword, required this.filter});

  final String keyword;
  final BangumiSearchFilter filter;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is BangumiSearchRequest &&
        other.keyword == keyword &&
        other.filter == filter;
  }

  @override
  int get hashCode => Object.hash(keyword, filter);
}

class BangumiLocalMatch {
  const BangumiLocalMatch({
    required this.mediaId,
    required this.status,
    required this.title,
  });

  final String mediaId;
  final UnifiedStatus status;
  final String title;
}

class BangumiPagedSearchState {
  const BangumiPagedSearchState({
    required this.total,
    required this.items,
    required this.pageSize,
    required this.isLoadingMore,
    this.loadMoreError,
  });

  factory BangumiPagedSearchState.fromSearchResult(
    BangumiSearchResult result, {
    required int pageSize,
  }) {
    return BangumiPagedSearchState(
      total: result.total,
      items: result.data,
      pageSize: pageSize,
      isLoadingMore: false,
    );
  }

  final int total;
  final List<BangumiSubjectDto> items;
  final int pageSize;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => items.length < total;

  BangumiPagedSearchState copyWith({
    int? total,
    List<BangumiSubjectDto>? items,
    int? pageSize,
    bool? isLoadingMore,
    Object? loadMoreError = _noOverride,
  }) {
    return BangumiPagedSearchState(
      total: total ?? this.total,
      items: items ?? this.items,
      pageSize: pageSize ?? this.pageSize,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: identical(loadMoreError, _noOverride)
          ? this.loadMoreError
          : loadMoreError,
    );
  }
}

const Object _noOverride = Object();

final bangumiLocalIndexProvider =
    StreamProvider.autoDispose<Map<int, BangumiLocalMatch>>((ref) {
      final logger = const StepLogger('bangumiLocalIndexProvider');
      final mediaRepository = ref.watch(mediaRepositoryProvider);

      return mediaRepository.watchLibrary().map((items) {
        /*
         * ====================================================================
         * 步骤1：构建本地 Bangumi 条目索引
         * ====================================================================
         * 目标：
         *   1) 把本地库里的 `sourceIdsJson` 折叠成搜索页可直接消费的索引
         *   2) 让搜索结果能实时展示已添加状态
         */
        logger.info('开始构建本地 Bangumi 条目索引...');

        // 1.1 逐条解析本地记录里的 bangumi sourceId
        final index = <int, BangumiLocalMatch>{};
        for (final item in items) {
          final bangumiId = SourceIdMap.get(
            item.mediaItem.sourceIdsJson,
            'bangumi',
          );
          final parsedBangumiId = int.tryParse(bangumiId ?? '');
          if (parsedBangumiId == null) {
            continue;
          }

          // 1.2 写入搜索页所需的 mediaId / status / title
          index[parsedBangumiId] = BangumiLocalMatch(
            mediaId: item.mediaItem.id,
            status: item.userEntry?.status ?? UnifiedStatus.wishlist,
            title: item.mediaItem.title,
          );
        }

        logger.info('本地 Bangumi 条目索引构建完成。');
        return index;
      });
    });

final bangumiSearchProvider = AsyncNotifierProvider.autoDispose
    .family<
      BangumiSearchController,
      BangumiPagedSearchState,
      BangumiSearchRequest
    >(BangumiSearchController.new);

class BangumiSearchController
    extends
        AutoDisposeFamilyAsyncNotifier<
          BangumiPagedSearchState,
          BangumiSearchRequest
        > {
  static const int _pageSize = 20;
  static const StepLogger logger = StepLogger('bangumiSearchController');

  late BangumiSearchRequest _request;

  @override
  Future<BangumiPagedSearchState> build(BangumiSearchRequest arg) async {
    /*
     * ====================================================================
     * 步骤2：执行 Bangumi 搜索首页请求
     * ====================================================================
     * 目标：
     *   1) 根据搜索词和类型筛选获取第一页 Bangumi 结果
     *   2) 为 Add 页的懒加载滚动提供稳定的首屏状态
     */
    logger.info('开始执行 Bangumi 搜索首页请求...');

    // 2.1 记录当前请求，并清理空关键词
    _request = arg;
    final normalizedKeyword = arg.keyword.trim();
    if (normalizedKeyword.isEmpty) {
      logger.info('Bangumi 搜索首页请求结束，空关键词直接返回。');
      return const BangumiPagedSearchState(
        total: 0,
        items: <BangumiSubjectDto>[],
        pageSize: _pageSize,
        isLoadingMore: false,
      );
    }

    // 2.2 拉取第一页结果，固定排除 music=3
    final result = await ref
        .watch(bangumiApiServiceProvider)
        .searchSubjects(
          normalizedKeyword,
          filter: <String, Object?>{'type': arg.filter.bangumiTypes},
          limit: _pageSize,
          offset: 0,
        );

    logger.info('Bangumi 搜索首页请求完成。');
    return BangumiPagedSearchState.fromSearchResult(
      result,
      pageSize: _pageSize,
    );
  }

  Future<void> loadMore() async {
    /*
     * ====================================================================
     * 步骤3：加载下一页 Bangumi 搜索结果
     * ====================================================================
     * 目标：
     *   1) 在用户下滚时继续请求下一页结果
     *   2) 保持已加载数据不闪烁，并能在底部展示加载状态
     */
    logger.info('开始加载下一页 Bangumi 搜索结果...');

    // 3.1 保护当前状态，避免空状态、重复加载和越界请求
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      logger.info('下一页 Bangumi 搜索结果加载跳过。');
      return;
    }

    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: null),
    );

    try {
      // 3.2 基于已加载数量继续请求下一页
      final result = await ref
          .read(bangumiApiServiceProvider)
          .searchSubjects(
            _request.keyword.trim(),
            filter: <String, Object?>{'type': _request.filter.bangumiTypes},
            limit: current.pageSize,
            offset: current.items.length,
          );

      // 3.3 追加新结果并按 subject id 去重，避免滚动重复卡片
      final merged = <BangumiSubjectDto>[
        ...current.items,
        ...result.data.where((item) {
          return current.items.every((existing) => existing.id != item.id);
        }),
      ];

      state = AsyncData(
        current.copyWith(
          total: result.total,
          items: merged,
          isLoadingMore: false,
          loadMoreError: null,
        ),
      );
      logger.info('下一页 Bangumi 搜索结果加载完成。');
    } catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error),
      );
      logger.info('下一页 Bangumi 搜索结果加载失败。');
    }
  }
}

final bangumiSubjectDetailProvider = FutureProvider.autoDispose
    .family<BangumiSubjectDto, int>((ref, subjectId) async {
      final logger = const StepLogger('bangumiSubjectDetailProvider');
      final bangumiApiService = ref.watch(bangumiApiServiceProvider);

      /*
       * ====================================================================
       * 步骤3：加载 Bangumi 条目详情
       * ====================================================================
       * 目标：
       *   1) 为搜索结果的 View 预览提供完整详情
       *   2) 复用 integration service 的 subject 缓存，避免重复请求
       */
      logger.info('开始加载 Bangumi 条目详情...');

      // 3.1 防御无效 subjectId，避免请求落到错误接口
      if (subjectId <= 0) {
        throw ArgumentError.value(
          subjectId,
          'subjectId',
          'Bangumi subject id must be positive.',
        );
      }

      // 3.2 调用 service 获取远程详情
      final subject = await bangumiApiService.getSubject(subjectId);

      logger.info('Bangumi 条目详情加载完成。');
      return subject;
    });

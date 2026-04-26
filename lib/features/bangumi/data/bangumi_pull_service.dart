import '../../../shared/data/app_database.dart';
import '../../../shared/data/repositories/media_repository.dart';
import '../../../shared/data/repositories/progress_repository.dart';
import '../../../shared/data/repositories/tag_repository.dart';
import '../../../shared/data/repositories/user_entry_repository.dart';
import '../../../shared/data/source_id_map.dart';
import '../../../shared/network/bangumi_api_client.dart';
import '../../../shared/utils/step_logger.dart';
import 'bangumi_api_service.dart';
import 'bangumi_models.dart';
import 'bangumi_subject_mapper.dart';
import 'bangumi_sync_status.dart';
import 'bangumi_type_mapper.dart';

class BangumiCollectionPullService implements BangumiPullService {
  BangumiCollectionPullService({
    required BangumiApiService apiService,
    required MediaRepository mediaRepository,
    required UserEntryRepository userEntryRepository,
    required ProgressRepository progressRepository,
    required TagRepository tagRepository,
    DateTime Function()? now,
    StepLogger? logger,
  }) : _apiService = apiService,
       _mediaRepository = mediaRepository,
       _userEntryRepository = userEntryRepository,
       _progressRepository = progressRepository,
       _tagRepository = tagRepository,
       _now = now ?? DateTime.now,
       _logger = logger ?? const StepLogger('BangumiCollectionPullService');

  static const int _pageSize = 30;

  final BangumiApiService _apiService;
  final MediaRepository _mediaRepository;
  final UserEntryRepository _userEntryRepository;
  final ProgressRepository _progressRepository;
  final TagRepository _tagRepository;
  final DateTime Function() _now;
  final StepLogger _logger;

  @override
  Future<BangumiPullSummary> pullCollections({
    required String username,
    required BangumiSyncTrigger trigger,
  }) async {
    /*
     * ========================================================================
     * 步骤1：分页拉取当前用户的 Bangumi 收藏
     * ========================================================================
     * 目标：
     *   1) 为 post-connect、startup、manual 三种触发器复用同一批量入口
     *   2) 把列表分页控制留在 Bangumi 集成层，不泄漏给 UI
     */
    _logger.info('开始分页拉取 Bangumi 收藏（${trigger.name}）...');

    // 1.1 归一化用户名，并初始化本次批量同步摘要
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      _logger.info('Bangumi 收藏分页拉取失败。');
      throw ArgumentError.value(
        username,
        'username',
        'Bangumi username cannot be empty.',
      );
    }

    final summary = _BangumiPullAccumulator();

    for (final subjectType in BangumiTypeMapper.supportedSubjectTypes) {
      var offset = 0;

      while (true) {
        // 1.2 按 subject_type 分页拉取，避免把 music 等无关类型带进来
        final page = await _apiService.listCollections(
          normalizedUsername,
          limit: _pageSize,
          offset: offset,
          subjectType: subjectType,
        );
        if (page.data.isEmpty) {
          break;
        }

        // 1.3 逐条合并到本地库，记录导入 / 更新 / 跳过 / localWins / failed
        for (final collection in page.data) {
          await _reconcileCollection(collection, summary: summary);
        }

        final nextOffset = page.offset + page.data.length;
        if (nextOffset >= page.total) {
          break;
        }
        offset = nextOffset;
      }
    }

    _logger.info('Bangumi 收藏分页拉取完成。');
    return summary.build();
  }

  Future<void> _reconcileCollection(
    BangumiCollectionDto collection, {
    required _BangumiPullAccumulator summary,
  }) async {
    /*
     * ========================================================================
     * 步骤2：把单条 Bangumi 收藏合并到本地库
     * ========================================================================
     * 目标：
     *   1) 按 bangumi subject id 对齐本地 media item
     *   2) 在 clean / dirty / missing 三种场景下执行对应的 local-first 合并
     */
    _logger.info('开始合并单条 Bangumi 收藏...');

    try {
      // 2.1 解析远端 subjectId、status、score
      final subjectId = collection.subjectId;
      if (subjectId <= 0) {
        summary.failedCount += 1;
        _logger.info('单条 Bangumi 收藏合并完成。');
        return;
      }

      final remoteStatus = _resolveRemoteStatus(collection.type);
      final remoteScore = _normalizeScore(collection.rate);
      final localItem = await _mediaRepository.findBySourceId(
        'bangumi',
        subjectId.toString(),
      );

      if (localItem == null) {
        // 2.2 本地缺失时新建媒体和 user entry，并落下同步戳
        final imported = await _importMissingCollection(
          subjectId: subjectId,
          collection: collection,
          remoteStatus: remoteStatus,
          remoteScore: remoteScore,
        );
        if (imported) {
          summary.importedCount += 1;
        } else {
          summary.skippedCount += 1;
        }
        _logger.info('单条 Bangumi 收藏合并完成。');
        return;
      }

      final localEntry = await _userEntryRepository.getByMediaItemId(
        localItem.id,
      );
      if (_isLocalDirty(localEntry)) {
        // 2.3 命中本地脏数据时保留本地值，只统计 localWins
        summary.localWinsCount += 1;
        _logger.info('单条 Bangumi 收藏合并完成。');
        return;
      }

      final syncedAt = _now();
      final shouldApplyRemote = _shouldApplyRemote(
        localEntry,
        remoteStatus: remoteStatus,
        remoteScore: remoteScore,
        remoteReview: collection.comment,
      );

      if (shouldApplyRemote) {
        await _userEntryRepository.applyRemoteCollectionFields(
          localItem.id,
          status: remoteStatus,
          score: remoteScore,
          review: collection.comment,
          syncedAt: syncedAt,
        );
        summary.updatedCount += 1;
      } else {
        await _userEntryRepository.markSynced(localItem.id, syncedAt);
        summary.skippedCount += 1;
      }

      await _mediaRepository.markSynced(localItem.id, syncedAt);
      await _reconcileCommunityRating(localItem.id, collection: collection);
      await _reconcileTags(localItem.id, collection: collection);

      // 步骤2.4：合并进度
      await _reconcileProgress(
        localItem.id,
        mediaItem: localItem,
        collection: collection,
        summary: summary,
      );

      _logger.info('单条 Bangumi 收藏合并完成。');
    } on BangumiUnauthorizedError {
      _logger.info('单条 Bangumi 收藏合并失败，授权已失效。');
      rethrow;
    } on BangumiApiException {
      summary.failedCount += 1;
      _logger.info('单条 Bangumi 收藏合并失败。');
    } on ArgumentError {
      summary.failedCount += 1;
      _logger.info('单条 Bangumi 收藏合并失败。');
    } on StateError {
      summary.failedCount += 1;
      _logger.info('单条 Bangumi 收藏合并失败。');
    }
  }

  Future<bool> _importMissingCollection({
    required int subjectId,
    required BangumiCollectionDto collection,
    required UnifiedStatus? remoteStatus,
    required int? remoteScore,
  }) async {
    /*
     * ========================================================================
     * 步骤3：导入本地不存在的 Bangumi 收藏
     * ========================================================================
     * 目标：
     *   1) 用 Bangumi subject 元数据补建本地媒体条目
     *   2) 把远端状态 / 评分写入默认 user entry，并留下同步戳
     */
    _logger.info('开始导入本地不存在的 Bangumi 收藏...');

    // 3.1 优先复用列表内嵌 subject，缺失时回退到 getSubject
    final subject = await _resolveSubject(collection);
    if (!BangumiTypeMapper.supportedSubjectTypes.contains(subject.type)) {
      _logger.info('导入本地不存在的 Bangumi 收藏完成。');
      return false;
    }

    final mediaDraft = BangumiSubjectMapper.toLocalMediaDraft(subject);

    // 3.2 先建本地媒体，再把远端 status / score 应用到 user entry
    final mediaItemId = await _mediaRepository.createItem(
      mediaType: mediaDraft.mediaType,
      title: mediaDraft.title,
      subtitle: mediaDraft.subtitle,
      posterUrl: mediaDraft.posterUrl,
      releaseDate: mediaDraft.releaseDate,
      overview: mediaDraft.overview,
      sourceIdsJson: SourceIdMap.encode(<String, String>{
        'bangumi': subjectId.toString(),
      }),
      runtimeMinutes: mediaDraft.runtimeMinutes,
      totalEpisodes: mediaDraft.totalEpisodes,
      totalPages: mediaDraft.totalPages,
      estimatedPlayHours: mediaDraft.estimatedPlayHours,
      communityScore: mediaDraft.communityScore,
      communityRatingCount: mediaDraft.communityRatingCount,
    );

    final syncedAt = _now();
    await _userEntryRepository.applyRemoteCollectionFields(
      mediaItemId,
      status: remoteStatus,
      score: remoteScore,
      review: collection.comment,
      syncedAt: syncedAt,
    );
    await _reconcileTags(
      mediaItemId,
      collection: collection,
      subject: subject,
      syncedAt: syncedAt,
    );

    // 3.3 若 Bangumi 中有进度，一并导入本地
    final int? importEpisode;
    final int? importPage;
    switch (mediaDraft.mediaType) {
      case MediaType.tv:
        importEpisode = collection.epStatus;
        importPage = null;
      case MediaType.book:
        importEpisode = null;
        importPage = collection.epStatus;
      case MediaType.movie:
      case MediaType.game:
        importEpisode = null;
        importPage = null;
    }
    if (importEpisode != null || importPage != null) {
      await _progressRepository.applyRemoteProgress(
        mediaItemId,
        currentEpisode: importEpisode,
        currentPage: importPage,
        syncedAt: syncedAt,
      );
    }

    await _mediaRepository.markSynced(mediaItemId, syncedAt);

    _logger.info('导入本地不存在的 Bangumi 收藏完成。');
    return true;
  }

  Future<BangumiSubjectDto> _resolveSubject(
    BangumiCollectionDto collection,
  ) async {
    final embeddedSubject = collection.subject;
    if (embeddedSubject != null &&
        BangumiTypeMapper.supportedSubjectTypes.contains(
          embeddedSubject.type,
        )) {
      return embeddedSubject;
    }

    return _apiService.getSubject(collection.subjectId);
  }

  UnifiedStatus? _resolveRemoteStatus(int? collectionType) {
    if (collectionType == null) {
      return null;
    }
    return BangumiTypeMapper.toUnifiedStatus(collectionType);
  }

  int? _normalizeScore(int? rate) {
    if (rate == null) {
      return null;
    }

    return rate.clamp(0, 10);
  }

  bool _shouldApplyRemote(
    UserEntry? localEntry, {
    required UnifiedStatus? remoteStatus,
    required int? remoteScore,
    required String? remoteReview,
  }) {
    if (localEntry == null) {
      return true;
    }

    final localStatus = localEntry.status;
    if (remoteStatus != null && localStatus != remoteStatus) {
      return true;
    }

    return localEntry.score != remoteScore ||
        _normalizeOptional(localEntry.review) !=
            _normalizeOptional(remoteReview);
  }

  Future<void> _reconcileCommunityRating(
    String mediaItemId, {
    required BangumiCollectionDto collection,
  }) async {
    /*
     * ========================================================================
     * 步骤4：合并 Bangumi 社区评分
     * ========================================================================
     * 目标：
     *   1) 从 collection 内嵌 subject 写入社区均分和评分人数
     *   2) 只作为展示数据覆盖更新，不参与用户评分冲突
     */
    _logger.info('开始合并 Bangumi 社区评分...');

    // 4.1 优先复用收藏列表内嵌 rating，缺失时回退到 subject 详情缓存
    final rating = await _resolveRating(collection);
    if (rating == null) {
      _logger.info('Bangumi 社区评分合并完成。');
      return;
    }

    // 4.2 写入 media_items 的 pull-only 展示字段
    await _mediaRepository.applyRemoteCommunityRating(
      mediaItemId,
      communityScore: rating.score,
      communityRatingCount: rating.total,
      syncedAt: _now(),
    );

    _logger.info('Bangumi 社区评分合并完成。');
  }

  Future<BangumiRatingDto?> _resolveRating(
    BangumiCollectionDto collection,
  ) async {
    final embeddedRating = collection.subject?.rating;
    if (embeddedRating != null) {
      return embeddedRating;
    }

    try {
      return (await _apiService.getSubject(collection.subjectId)).rating;
    } on BangumiApiException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _reconcileTags(
    String mediaItemId, {
    required BangumiCollectionDto collection,
    BangumiSubjectDto? subject,
    DateTime? syncedAt,
  }) async {
    /*
     * ========================================================================
     * 步骤5：合并 Bangumi 标签
     * ========================================================================
     * 目标：
     *   1) 把远端收藏 tags 和 subject 公共 tags 追加进本地标签表和关联表
     *   2) 不删除本地已有额外标签，保持加法合并策略
     */
    _logger.info('开始合并 Bangumi 标签...');

    // 5.1 合并收藏标签和 subject 公共标签，远端无标签时跳过
    final tags = await _resolveTags(collection, subject: subject);
    if (tags.isEmpty) {
      _logger.info('Bangumi 标签合并完成。');
      return;
    }

    // 5.2 只追加或恢复远端标签关联，并标记为已同步
    await _tagRepository.addTagsForMedia(
      mediaItemId,
      tags,
      syncedAt: syncedAt ?? _now(),
    );

    _logger.info('Bangumi 标签合并完成。');
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<List<String>> _resolveTags(
    BangumiCollectionDto collection, {
    BangumiSubjectDto? subject,
  }) async {
    final embeddedTags = _mergeTags(<String>[
      ...collection.tags,
      ...((subject ?? collection.subject)?.tags ?? const <String>[]),
    ]);
    if (embeddedTags.isNotEmpty) {
      return embeddedTags;
    }

    try {
      final detailSubject = await _apiService.getSubject(collection.subjectId);
      return _mergeTags(<String>[...collection.tags, ...detailSubject.tags]);
    } on BangumiApiException {
      return collection.tags;
    } on ArgumentError {
      return collection.tags;
    }
  }

  List<String> _mergeTags(List<String> values) {
    final seen = <String>{};
    final merged = <String>[];
    for (final value in values) {
      final tag = _normalizeOptional(value);
      if (tag == null) {
        continue;
      }

      final key = tag.toLowerCase();
      if (seen.add(key)) {
        merged.add(tag);
      }
    }
    return merged;
  }

  Future<void> _reconcileProgress(
    String mediaItemId, {
    required MediaItem mediaItem,
    required BangumiCollectionDto collection,
    required _BangumiPullAccumulator summary,
  }) async {
    _logger.info('开始合并 Bangumi 进度...');

    final remoteEpStatus = collection.epStatus;
    if (remoteEpStatus == null) {
      _logger.info('Bangumi 进度合并完成（远端无进度）。');
      return;
    }

    final localProgress = await _progressRepository.getByMediaItemId(
      mediaItemId,
    );

    if (_isProgressDirty(localProgress)) {
      summary.localWinsCount += 1;
      _logger.info('Bangumi 进度合并完成（本地脏数据，保留本地）。');
      return;
    }

    final (int? currentEpisode, int? currentPage, double? currentMinutes)
    progressTuple = switch (mediaItem.mediaType) {
      MediaType.tv => (remoteEpStatus, null, null),
      MediaType.book => (null, remoteEpStatus, null),
      MediaType.movie || MediaType.game => (null, null, null),
    };

    if (progressTuple.$1 == null &&
        progressTuple.$2 == null &&
        progressTuple.$3 == null) {
      _logger.info('Bangumi 进度合并完成（媒体类型不支持进度映射）。');
      return;
    }

    final existingProgress = await _progressRepository.getByMediaItemId(
      mediaItemId,
    );
    final bool shouldApply = _shouldApplyProgress(
      existingProgress,
      currentEpisode: progressTuple.$1,
      currentPage: progressTuple.$2,
      currentMinutes: progressTuple.$3,
    );

    if (shouldApply) {
      final syncedAt = _now();
      await _progressRepository.applyRemoteProgress(
        mediaItemId,
        currentEpisode: progressTuple.$1,
        currentPage: progressTuple.$2,
        currentMinutes: progressTuple.$3,
        syncedAt: syncedAt,
      );
      // Note: updatedCount is already incremented by status/score merge if applicable
    } else {
      summary.skippedCount += 1;
    }

    _logger.info('Bangumi 进度合并完成。');
  }

  bool _isProgressDirty(ProgressEntry? progress) {
    if (progress == null) return false;
    final lastSyncedAt = progress.lastSyncedAt;
    if (lastSyncedAt == null) return false;
    return progress.updatedAt.isAfter(lastSyncedAt);
  }

  bool _shouldApplyProgress(
    ProgressEntry? progress, {
    required int? currentEpisode,
    required int? currentPage,
    required double? currentMinutes,
  }) {
    if (progress == null) return true;
    return progress.currentEpisode != currentEpisode ||
        progress.currentPage != currentPage ||
        progress.currentMinutes != currentMinutes;
  }

  bool _isLocalDirty(UserEntry? localEntry) {
    if (localEntry == null) {
      return false;
    }

    final lastSyncedAt = localEntry.lastSyncedAt;
    if (lastSyncedAt != null) {
      return localEntry.updatedAt.isAfter(lastSyncedAt);
    }

    return localEntry.score != null ||
        localEntry.status != UnifiedStatus.wishlist;
  }
}

class _BangumiPullAccumulator {
  int importedCount = 0;
  int updatedCount = 0;
  int skippedCount = 0;
  int localWinsCount = 0;
  int failedCount = 0;

  BangumiPullSummary build() {
    return BangumiPullSummary(
      importedCount: importedCount,
      updatedCount: updatedCount,
      skippedCount: skippedCount,
      localWinsCount: localWinsCount,
      failedCount: failedCount,
    );
  }
}

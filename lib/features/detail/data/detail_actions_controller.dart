import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/bangumi/data/bangumi_progress_sync_service.dart';
import '../../../features/bangumi/data/bangumi_sync_service.dart';
import '../../../features/bangumi/data/providers.dart';
import '../../../shared/data/app_database.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/data/repositories/activity_log_repository.dart';
import '../../../shared/data/repositories/media_repository.dart';
import '../../../shared/data/repositories/progress_repository.dart';
import '../../../shared/data/repositories/shelf_repository.dart';
import '../../../shared/data/repositories/tag_repository.dart';
import '../../../shared/data/repositories/user_entry_repository.dart';

class DetailEntryUpdateInput {
  const DetailEntryUpdateInput({
    required this.mediaType,
    required this.status,
    required this.score,
    required this.progressValue,
    required this.review,
    required this.notes,
    required this.tags,
    required this.shelves,
  });

  final MediaType mediaType;
  final UnifiedStatus status;
  final int? score;
  final double? progressValue;
  final String? review;
  final String? notes;
  final List<String> tags;
  final List<String> shelves;
}

final detailActionsControllerProvider = Provider<DetailActionsController>((
  ref,
) {
  return DetailActionsController(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    userEntryRepository: ref.watch(userEntryRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    shelfRepository: ref.watch(shelfRepositoryProvider),
    activityLogRepository: ref.watch(activityLogRepositoryProvider),
    bangumiSyncService: ref.watch(bangumiSyncServiceProvider),
    bangumiProgressSyncService: ref.watch(bangumiProgressSyncServiceProvider),
  );
});

class DetailActionsController {
  DetailActionsController({
    required MediaRepository mediaRepository,
    required UserEntryRepository userEntryRepository,
    required ProgressRepository progressRepository,
    required TagRepository tagRepository,
    required ShelfRepository shelfRepository,
    required ActivityLogRepository activityLogRepository,
    required BangumiSyncService bangumiSyncService,
    required BangumiProgressSyncService bangumiProgressSyncService,
  }) : _mediaRepository = mediaRepository,
       _userEntryRepository = userEntryRepository,
       _progressRepository = progressRepository,
       _tagRepository = tagRepository,
       _shelfRepository = shelfRepository,
       _activityLogRepository = activityLogRepository,
       _bangumiSyncService = bangumiSyncService,
       _bangumiProgressSyncService = bangumiProgressSyncService;

  final MediaRepository _mediaRepository;
  final UserEntryRepository _userEntryRepository;
  final ProgressRepository _progressRepository;
  final TagRepository _tagRepository;
  final ShelfRepository _shelfRepository;
  final ActivityLogRepository _activityLogRepository;
  final BangumiSyncService _bangumiSyncService;
  final BangumiProgressSyncService _bangumiProgressSyncService;

  Future<void> applyQuickStatus(
    String mediaItemId,
    UnifiedStatus status,
  ) async {
    /*
     * ========================================================================
     * 步骤1：更新详情页快捷状态并触发同步
     * ========================================================================
     * 目标：
     *   1) 保持本地状态写入仍然先于远端副作用
     *   2) 让详情页快捷动作与 Quick Add 共享同一同步合同
     */

    // 1.1 读取当前状态；未变化时直接跳过
    final currentEntry = await _userEntryRepository.getByMediaItemId(
      mediaItemId,
    );
    final currentStatus = currentEntry?.status ?? UnifiedStatus.wishlist;
    if (currentStatus == status) {
      return;
    }

    // 1.2 先更新本地状态与 activity log
    await _updateStatusWithLog(mediaItemId, from: currentStatus, to: status);

    // 1.3 本地落库完成后再触发 Bangumi 推送
    await _bangumiSyncService.pushCollection(
      mediaItemId: mediaItemId,
      status: status,
    );

    // 1.4 状态变为 done 时，若 TV 类型有总集数，同步推送进度
    if (status == UnifiedStatus.done) {
      final mediaItem = await _mediaRepository.getItem(mediaItemId);
      if (mediaItem != null &&
          mediaItem.mediaType == MediaType.tv &&
          mediaItem.totalEpisodes != null) {
        await _progressRepository.updateProgress(
          mediaItemId,
          currentEpisode: mediaItem.totalEpisodes,
        );
        await _bangumiProgressSyncService.pushProgress(
          mediaItemId: mediaItemId,
        );
      }
    }
  }

  Future<void> saveChanges(
    String mediaItemId,
    DetailEntryUpdateInput input,
  ) async {
    /*
     * ========================================================================
     * 步骤2：保存详情页编辑结果并按差异触发同步
     * ========================================================================
     * 目标：
     *   1) 先完成本地状态、评分、进度、笔记等写入
     *   2) 仅在 Bangumi 收藏字段变化时触发一次 Bangumi 推送
     */

    // 2.1 读取本地基线数据，确定哪些字段真正发生变化
    final mediaItem = await _mediaRepository.getItem(mediaItemId);
    if (mediaItem == null) {
      throw StateError('Media item not found.');
    }

    final currentEntry = await _userEntryRepository.getByMediaItemId(
      mediaItemId,
    );
    final currentProgress = await _progressRepository.getByMediaItemId(
      mediaItemId,
    );
    final currentTags = await _tagRepository.getByMediaItemId(mediaItemId);

    final currentStatus = currentEntry?.status ?? UnifiedStatus.wishlist;
    final statusChanged = currentStatus != input.status;
    final scoreChanged = currentEntry?.score != input.score;
    final normalizedReview = _normalizeOptional(input.review);
    final reviewChanged =
        _normalizeOptional(currentEntry?.review) != normalizedReview;

    // 2.2 状态变化时先更新本地 user entry 和 activity log
    if (statusChanged) {
      await _updateStatusWithLog(
        mediaItemId,
        from: currentStatus,
        to: input.status,
      );
    }

    // 2.3 评分变化时写入本地分数和日志
    if (scoreChanged) {
      await _userEntryRepository.updateScore(mediaItemId, input.score);
      await _activityLogRepository.appendEvent(
        mediaItemId,
        ActivityEvent.scoreChanged,
        payload: <String, Object?>{'score': input.score},
      );
    }

    // 2.4 其余本地字段继续按原有差异逻辑更新
    if (!_sameProgress(
      mediaItem.mediaType,
      currentProgress,
      input.progressValue,
    )) {
      final progressUpdate = _buildProgressUpdate(
        mediaItem,
        input.progressValue,
      );

      await _progressRepository.updateProgress(
        mediaItemId,
        currentEpisode: progressUpdate.currentEpisode,
        currentPage: progressUpdate.currentPage,
        currentMinutes: progressUpdate.currentMinutes,
        completionRatio: progressUpdate.completionRatio,
      );

      await _activityLogRepository.appendEvent(
        mediaItemId,
        ActivityEvent.progressChanged,
        payload: <String, Object?>{
          'field': progressUpdate.fieldName,
          'value': input.progressValue,
          'summary': _progressSummary(mediaItem, input.progressValue),
        },
      );
    }

    final normalizedNotes = _normalizeOptional(input.notes);
    if (_normalizeOptional(currentEntry?.notes) != normalizedNotes) {
      await _userEntryRepository.updateNotes(mediaItemId, normalizedNotes);
      await _activityLogRepository.appendEvent(
        mediaItemId,
        ActivityEvent.noteEdited,
        payload: <String, Object?>{'hasNotes': normalizedNotes != null},
      );
    }

    // 2.5 公开短评变化时写入本地 review；notes 仍作为私有笔记独立保存
    if (reviewChanged) {
      await _userEntryRepository.updateReview(mediaItemId, normalizedReview);
    }

    await _tagRepository.syncTagsForMedia(mediaItemId, input.tags);
    await _shelfRepository.syncShelvesForMedia(mediaItemId, input.shelves);

    final tagsChanged = !_sameStringList(
      currentTags.map((tag) => tag.name).toList(growable: false),
      input.tags,
    );

    // 2.6 本地字段全部落库后，再统一触发 Bangumi 推送
    if (statusChanged || reviewChanged || tagsChanged) {
      await _bangumiSyncService.pushCollection(
        mediaItemId: mediaItemId,
        status: input.status,
        score: input.score,
        review: normalizedReview,
        tags: input.tags,
      );
    } else if (scoreChanged) {
      await _bangumiSyncService.pushCollection(
        mediaItemId: mediaItemId,
        score: input.score,
      );
    }

    // 2.7 进度变化时触发 Bangumi 进度推送
    if (!_sameProgress(
      mediaItem.mediaType,
      currentProgress,
      input.progressValue,
    )) {
      await _bangumiProgressSyncService.pushProgress(mediaItemId: mediaItemId);
    }
  }

  Future<void> delete(String mediaItemId) async {
    await _mediaRepository.softDelete(mediaItemId);
  }

  Future<void> _updateStatusWithLog(
    String mediaItemId, {
    required UnifiedStatus from,
    required UnifiedStatus to,
  }) async {
    await _userEntryRepository.updateStatus(mediaItemId, to);
    await _activityLogRepository.appendEvent(
      mediaItemId,
      ActivityEvent.statusChanged,
      payload: <String, Object?>{'from': from.name, 'to': to.name},
    );

    if (to == UnifiedStatus.done) {
      await _activityLogRepository.appendEvent(
        mediaItemId,
        ActivityEvent.completed,
        payload: const <String, Object?>{},
      );
    }
  }

  bool _sameProgress(
    MediaType mediaType,
    ProgressEntry? currentProgress,
    double? nextValue,
  ) {
    switch (mediaType) {
      case MediaType.tv:
        return currentProgress?.currentEpisode == nextValue?.round();
      case MediaType.book:
        return currentProgress?.currentPage == nextValue?.round();
      case MediaType.movie:
        return _sameDouble(currentProgress?.currentMinutes, nextValue);
      case MediaType.game:
        return _sameDouble(
          currentProgress?.currentMinutes == null
              ? null
              : currentProgress!.currentMinutes! / 60,
          nextValue,
        );
    }
  }

  _ProgressUpdate _buildProgressUpdate(MediaItem mediaItem, double? value) {
    switch (mediaItem.mediaType) {
      case MediaType.tv:
        final episodes = value?.round();
        return _ProgressUpdate(
          fieldName: 'currentEpisode',
          currentEpisode: episodes,
          completionRatio: _ratio(
            episodes?.toDouble(),
            mediaItem.totalEpisodes?.toDouble(),
          ),
        );
      case MediaType.book:
        final pages = value?.round();
        return _ProgressUpdate(
          fieldName: 'currentPage',
          currentPage: pages,
          completionRatio: _ratio(
            pages?.toDouble(),
            mediaItem.totalPages?.toDouble(),
          ),
        );
      case MediaType.movie:
        return _ProgressUpdate(
          fieldName: 'currentMinutes',
          currentMinutes: value,
          completionRatio: _ratio(value, mediaItem.runtimeMinutes?.toDouble()),
        );
      case MediaType.game:
        final minutes = value == null ? null : value * 60;
        return _ProgressUpdate(
          fieldName: 'currentMinutes',
          currentMinutes: minutes,
          completionRatio: _ratio(value, mediaItem.estimatedPlayHours),
        );
    }
  }

  double? _ratio(double? current, double? total) {
    if (current == null || total == null || total <= 0) {
      return null;
    }
    return (current / total).clamp(0, 1);
  }

  bool _sameDouble(double? left, double? right) {
    if (left == null || right == null) {
      return left == right;
    }
    return (left - right).abs() < 0.001;
  }

  String _progressSummary(MediaItem mediaItem, double? value) {
    if (value == null) {
      return 'Progress cleared';
    }

    switch (mediaItem.mediaType) {
      case MediaType.tv:
        if (mediaItem.totalEpisodes != null) {
          return 'Episode ${value.round()} / ${mediaItem.totalEpisodes}';
        }
        return 'Episode ${value.round()}';
      case MediaType.book:
        if (mediaItem.totalPages != null) {
          return 'Page ${value.round()} / ${mediaItem.totalPages}';
        }
        return 'Page ${value.round()}';
      case MediaType.movie:
        if (mediaItem.runtimeMinutes != null) {
          return '${value.round()} / ${mediaItem.runtimeMinutes} min';
        }
        return '${value.round()} min';
      case MediaType.game:
        if (mediaItem.estimatedPlayHours != null) {
          return '${value.toStringAsFixed(1)} / ${mediaItem.estimatedPlayHours!.toStringAsFixed(1)} h';
        }
        return '${value.toStringAsFixed(1)} h';
    }
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _sameStringList(List<String> left, List<String> right) {
    final normalizedLeft = _normalizeList(left);
    final normalizedRight = _normalizeList(right);
    if (normalizedLeft.length != normalizedRight.length) {
      return false;
    }

    for (var index = 0; index < normalizedLeft.length; index += 1) {
      if (normalizedLeft[index] != normalizedRight[index]) {
        return false;
      }
    }

    return true;
  }

  List<String> _normalizeList(List<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        normalized.add(key);
      }
    }
    normalized.sort();
    return normalized;
  }
}

class _ProgressUpdate {
  const _ProgressUpdate({
    required this.fieldName,
    this.currentEpisode,
    this.currentPage,
    this.currentMinutes,
    this.completionRatio,
  });

  final String fieldName;
  final int? currentEpisode;
  final int? currentPage;
  final double? currentMinutes;
  final double? completionRatio;
}

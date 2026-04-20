import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.notes,
    required this.tags,
    required this.shelves,
  });

  final MediaType mediaType;
  final UnifiedStatus status;
  final int? score;
  final double? progressValue;
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
  }) : _mediaRepository = mediaRepository,
       _userEntryRepository = userEntryRepository,
       _progressRepository = progressRepository,
       _tagRepository = tagRepository,
       _shelfRepository = shelfRepository,
       _activityLogRepository = activityLogRepository;

  final MediaRepository _mediaRepository;
  final UserEntryRepository _userEntryRepository;
  final ProgressRepository _progressRepository;
  final TagRepository _tagRepository;
  final ShelfRepository _shelfRepository;
  final ActivityLogRepository _activityLogRepository;

  Future<void> applyQuickStatus(
    String mediaItemId,
    UnifiedStatus status,
  ) async {
    final currentEntry = await _userEntryRepository.getByMediaItemId(
      mediaItemId,
    );
    final currentStatus = currentEntry?.status ?? UnifiedStatus.wishlist;
    if (currentStatus == status) {
      return;
    }

    await _updateStatusWithLog(mediaItemId, from: currentStatus, to: status);
  }

  Future<void> saveChanges(
    String mediaItemId,
    DetailEntryUpdateInput input,
  ) async {
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

    final currentStatus = currentEntry?.status ?? UnifiedStatus.wishlist;
    if (currentStatus != input.status) {
      await _updateStatusWithLog(
        mediaItemId,
        from: currentStatus,
        to: input.status,
      );
    }

    if (currentEntry?.score != input.score) {
      await _userEntryRepository.updateScore(mediaItemId, input.score);
      await _activityLogRepository.appendEvent(
        mediaItemId,
        ActivityEvent.scoreChanged,
        payload: <String, Object?>{'score': input.score},
      );
    }

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

    await _tagRepository.syncTagsForMedia(mediaItemId, input.tags);
    await _shelfRepository.syncShelvesForMedia(mediaItemId, input.shelves);
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

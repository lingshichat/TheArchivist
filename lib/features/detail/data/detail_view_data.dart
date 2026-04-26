import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/daos/media_dao.dart';
import '../../../shared/data/local_view_adapters.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/data/stream_combine.dart';
import '../../../shared/widgets/poster_view_data.dart';

class DetailNotesEntry {
  const DetailNotesEntry({required this.date, required this.body});

  final String date;
  final String body;
}

class DetailReviewEntry {
  const DetailReviewEntry({required this.body});

  final String body;
}

class DetailLifecycleEntry {
  const DetailLifecycleEntry({
    required this.title,
    required this.time,
    this.current = false,
  });

  final String title;
  final String time;
  final bool current;
}

class DetailViewData {
  const DetailViewData({
    required this.mediaId,
    required this.mediaType,
    required this.poster,
    required this.archiveId,
    required this.status,
    required this.progressLabel,
    required this.progressSummary,
    required this.progressRatio,
    required this.progressValue,
    required this.primaryActionLabel,
    required this.primaryActionStatus,
    required this.score,
    required this.communityRatingLabel,
    required this.lifecycle,
    required this.updateCount,
    this.synopsis,
    this.tags = const <String>[],
    this.shelves = const <String>[],
    this.review,
    this.notes,
  });

  final String mediaId;
  final MediaType mediaType;
  final PosterViewData poster;
  final String archiveId;
  final UnifiedStatus status;
  final String progressLabel;
  final String progressSummary;
  final double progressRatio;
  final double? progressValue;
  final String primaryActionLabel;
  final UnifiedStatus primaryActionStatus;
  final int? score;
  final String communityRatingLabel;
  final String? synopsis;
  final List<String> tags;
  final List<String> shelves;
  final DetailReviewEntry? review;
  final DetailNotesEntry? notes;
  final List<DetailLifecycleEntry> lifecycle;
  final int updateCount;

  bool get hasSynopsis => synopsis != null && synopsis!.isNotEmpty;
  bool get hasTags => tags.isNotEmpty;
  bool get hasShelves => shelves.isNotEmpty;
  bool get hasReview => review != null;
  bool get hasNotes => notes != null;
  bool get hasLifecycle => lifecycle.isNotEmpty;
}

final detailViewDataProvider = StreamProvider.family<DetailViewData?, String>((
  ref,
  id,
) {
  final mediaRepository = ref.watch(mediaRepositoryProvider);
  final tagRepository = ref.watch(tagRepositoryProvider);
  final shelfRepository = ref.watch(shelfRepositoryProvider);
  final activityLogRepository = ref.watch(activityLogRepositoryProvider);

  return combineLatest4(
    mediaRepository.watchDetailBase(id),
    tagRepository.watchByMediaItemId(id),
    shelfRepository.watchByMediaItemId(id),
    activityLogRepository.watchByMediaItemId(id),
    (
      MediaItemWithUserEntry? base,
      List<Tag> tags,
      List<ShelfList> shelves,
      List<ActivityLog> logs,
    ) {
      if (base == null) {
        return null;
      }

      final notes = _buildNotes(
        notesBody: base.userEntry?.notes,
        logs: logs,
        fallbackTime: base.userEntry?.updatedAt ?? base.mediaItem.updatedAt,
      );
      final review = _buildReview(reviewBody: base.userEntry?.review);

      return DetailViewData(
        mediaId: base.mediaItem.id,
        mediaType: base.mediaItem.mediaType,
        poster: LocalViewAdapters.toPosterView(base),
        archiveId: LocalViewAdapters.archiveIdLabel(base.mediaItem.id),
        status: base.userEntry?.status ?? UnifiedStatus.wishlist,
        progressLabel: _progressLabel(base.mediaItem.mediaType),
        progressSummary: LocalViewAdapters.buildProgressSummary(
          base.mediaItem,
          base.progressEntry,
        ),
        progressRatio: LocalViewAdapters.buildProgressRatio(
          base.mediaItem,
          base.progressEntry,
        ),
        progressValue: _progressValue(
          base.mediaItem.mediaType,
          base.progressEntry,
        ),
        primaryActionLabel: _primaryActionLabel(base.userEntry?.status),
        primaryActionStatus: _primaryActionStatus(base.userEntry?.status),
        score: base.userEntry?.score,
        communityRatingLabel: _buildCommunityRatingLabel(base.mediaItem),
        synopsis: base.mediaItem.overview,
        tags: tags.map((tag) => tag.name).toList(),
        shelves: shelves.map((shelf) => shelf.name).toList(),
        review: review,
        notes: notes,
        lifecycle: _buildLifecycle(logs),
        updateCount: logs.length,
      );
    },
  );
});

DetailNotesEntry? _buildNotes({
  required String? notesBody,
  required List<ActivityLog> logs,
  required DateTime fallbackTime,
}) {
  final resolvedNotes = notesBody?.trim();
  if (resolvedNotes == null || resolvedNotes.isEmpty) {
    return null;
  }

  DateTime noteTime = fallbackTime;
  for (final log in logs) {
    if (log.event == ActivityEvent.noteEdited) {
      noteTime = log.createdAt;
      break;
    }
  }

  return DetailNotesEntry(
    date: LocalViewAdapters.formatDateTime(noteTime),
    body: resolvedNotes,
  );
}

DetailReviewEntry? _buildReview({required String? reviewBody}) {
  final resolvedReview = reviewBody?.trim();
  if (resolvedReview == null || resolvedReview.isEmpty) {
    return null;
  }

  return DetailReviewEntry(body: resolvedReview);
}

String _buildCommunityRatingLabel(MediaItem mediaItem) {
  final score = mediaItem.communityScore;
  final count = mediaItem.communityRatingCount;
  if (score == null) {
    return 'Unknown';
  }

  final scoreText = score.toStringAsFixed(1);
  if (count == null || count <= 0) {
    return '$scoreText/10';
  }

  return '$scoreText/10 · $count votes';
}

List<DetailLifecycleEntry> _buildLifecycle(List<ActivityLog> logs) {
  return List<DetailLifecycleEntry>.generate(logs.length, (index) {
    final log = logs[index];
    return DetailLifecycleEntry(
      title: _activityTitle(log),
      time: LocalViewAdapters.formatDateTime(log.createdAt),
      current: index == 0,
    );
  });
}

String _activityTitle(ActivityLog log) {
  final payload = _decodePayload(log.payloadJson);

  switch (log.event) {
    case ActivityEvent.added:
      return 'ADDED TO COLLECTION';
    case ActivityEvent.statusChanged:
      final nextStatus = payload['to'] as String?;
      return 'STATUS UPDATED: ${_statusNameFromStorage(nextStatus).toUpperCase()}';
    case ActivityEvent.scoreChanged:
      final score = payload['score'];
      if (score == null) {
        return 'RATING CLEARED';
      }
      return 'RATING UPDATED: $score/10';
    case ActivityEvent.progressChanged:
      final summary = payload['summary'] as String?;
      if (summary == null || summary.isEmpty) {
        return 'PROGRESS UPDATED';
      }
      return 'PROGRESS UPDATED: $summary';
    case ActivityEvent.noteEdited:
      final hasNotes = payload['hasNotes'] == true;
      return hasNotes ? 'NOTES UPDATED' : 'NOTES CLEARED';
    case ActivityEvent.completed:
      return 'MARKED COMPLETED';
  }
}

Map<String, Object?> _decodePayload(String payloadJson) {
  final decoded = jsonDecode(payloadJson);
  if (decoded is Map<String, dynamic>) {
    return Map<String, Object?>.from(decoded);
  }
  return const <String, Object?>{};
}

String _progressLabel(MediaType mediaType) {
  switch (mediaType) {
    case MediaType.tv:
      return 'EPISODE PROGRESS';
    case MediaType.book:
      return 'PAGE PROGRESS';
    case MediaType.movie:
      return 'RUNTIME PROGRESS';
    case MediaType.game:
      return 'PLAYTIME';
  }
}

double? _progressValue(MediaType mediaType, ProgressEntry? progressEntry) {
  switch (mediaType) {
    case MediaType.tv:
      return progressEntry?.currentEpisode?.toDouble();
    case MediaType.book:
      return progressEntry?.currentPage?.toDouble();
    case MediaType.movie:
      return progressEntry?.currentMinutes;
    case MediaType.game:
      if (progressEntry?.currentMinutes == null) {
        return null;
      }
      return progressEntry!.currentMinutes! / 60;
  }
}

String _primaryActionLabel(UnifiedStatus? status) {
  switch (status ?? UnifiedStatus.wishlist) {
    case UnifiedStatus.wishlist:
      return 'Start Tracking';
    case UnifiedStatus.inProgress:
      return 'Mark Completed';
    case UnifiedStatus.done:
      return 'Reopen Entry';
    case UnifiedStatus.onHold:
      return 'Resume Tracking';
    case UnifiedStatus.dropped:
      return 'Restart Entry';
  }
}

UnifiedStatus _primaryActionStatus(UnifiedStatus? status) {
  switch (status ?? UnifiedStatus.wishlist) {
    case UnifiedStatus.wishlist:
      return UnifiedStatus.inProgress;
    case UnifiedStatus.inProgress:
      return UnifiedStatus.done;
    case UnifiedStatus.done:
      return UnifiedStatus.inProgress;
    case UnifiedStatus.onHold:
      return UnifiedStatus.inProgress;
    case UnifiedStatus.dropped:
      return UnifiedStatus.inProgress;
  }
}

String _statusNameFromStorage(String? value) {
  switch (value) {
    case 'wishlist':
      return 'Wishlist';
    case 'inProgress':
      return 'In Progress';
    case 'done':
      return 'Completed';
    case 'onHold':
      return 'On Hold';
    case 'dropped':
      return 'Dropped';
    default:
      return 'Wishlist';
  }
}

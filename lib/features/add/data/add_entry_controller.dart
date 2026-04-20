import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/data/repositories/activity_log_repository.dart';
import '../../../shared/data/repositories/media_repository.dart';
import '../../../shared/data/repositories/shelf_repository.dart';
import '../../../shared/data/repositories/tag_repository.dart';

class AddEntryInput {
  const AddEntryInput({
    required this.mediaType,
    required this.title,
    this.subtitle,
    this.releaseDate,
    this.overview,
    this.runtimeMinutes,
    this.totalEpisodes,
    this.totalPages,
    this.estimatedPlayHours,
    this.tags = const <String>[],
    this.shelves = const <String>[],
  });

  final MediaType mediaType;
  final String title;
  final String? subtitle;
  final DateTime? releaseDate;
  final String? overview;
  final int? runtimeMinutes;
  final int? totalEpisodes;
  final int? totalPages;
  final double? estimatedPlayHours;
  final List<String> tags;
  final List<String> shelves;
}

final addEntryControllerProvider = Provider<AddEntryController>((ref) {
  return AddEntryController(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    shelfRepository: ref.watch(shelfRepositoryProvider),
    activityLogRepository: ref.watch(activityLogRepositoryProvider),
  );
});

class AddEntryController {
  AddEntryController({
    required MediaRepository mediaRepository,
    required TagRepository tagRepository,
    required ShelfRepository shelfRepository,
    required ActivityLogRepository activityLogRepository,
  }) : _mediaRepository = mediaRepository,
       _tagRepository = tagRepository,
       _shelfRepository = shelfRepository,
       _activityLogRepository = activityLogRepository;

  final MediaRepository _mediaRepository;
  final TagRepository _tagRepository;
  final ShelfRepository _shelfRepository;
  final ActivityLogRepository _activityLogRepository;

  Future<String> create(AddEntryInput input) async {
    final mediaId = await _mediaRepository.createItem(
      mediaType: input.mediaType,
      title: input.title.trim(),
      subtitle: _normalizeOptional(input.subtitle),
      releaseDate: input.releaseDate,
      overview: _normalizeOptional(input.overview),
      runtimeMinutes: input.runtimeMinutes,
      totalEpisodes: input.totalEpisodes,
      totalPages: input.totalPages,
      estimatedPlayHours: input.estimatedPlayHours,
    );

    await _tagRepository.syncTagsForMedia(mediaId, input.tags);
    await _shelfRepository.syncShelvesForMedia(mediaId, input.shelves);

    await _activityLogRepository.appendEvent(
      mediaId,
      ActivityEvent.added,
      payload: <String, Object?>{
        'mediaType': input.mediaType.name,
        'title': input.title.trim(),
      },
    );

    return mediaId;
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

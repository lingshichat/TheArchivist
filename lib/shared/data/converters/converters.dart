import 'package:drift/drift.dart';

import '../tables/enums.dart';

class StatusConverter extends TypeConverter<UnifiedStatus, String> {
  const StatusConverter();

  static const _map = {
    UnifiedStatus.wishlist: 'wishlist',
    UnifiedStatus.inProgress: 'inProgress',
    UnifiedStatus.done: 'done',
    UnifiedStatus.onHold: 'onHold',
    UnifiedStatus.dropped: 'dropped',
  };

  @override
  UnifiedStatus fromSql(String fromDb) {
    return _map.entries
        .firstWhere(
          (e) => e.value == fromDb,
          orElse: () => const MapEntry(UnifiedStatus.wishlist, 'wishlist'),
        )
        .key;
  }

  @override
  String toSql(UnifiedStatus value) => _map[value]!;
}

class MediaTypeConverter extends TypeConverter<MediaType, String> {
  const MediaTypeConverter();

  static const _map = {
    MediaType.movie: 'movie',
    MediaType.tv: 'tv',
    MediaType.book: 'book',
    MediaType.game: 'game',
  };

  @override
  MediaType fromSql(String fromDb) {
    return _map.entries
        .firstWhere(
          (e) => e.value == fromDb,
          orElse: () => const MapEntry(MediaType.movie, 'movie'),
        )
        .key;
  }

  @override
  String toSql(MediaType value) => _map[value]!;
}

class ActivityEventConverter extends TypeConverter<ActivityEvent, String> {
  const ActivityEventConverter();

  static const _map = {
    ActivityEvent.added: 'added',
    ActivityEvent.statusChanged: 'statusChanged',
    ActivityEvent.scoreChanged: 'scoreChanged',
    ActivityEvent.progressChanged: 'progressChanged',
    ActivityEvent.noteEdited: 'noteEdited',
    ActivityEvent.completed: 'completed',
  };

  @override
  ActivityEvent fromSql(String fromDb) {
    return _map.entries
        .firstWhere(
          (e) => e.value == fromDb,
          orElse: () => const MapEntry(ActivityEvent.added, 'added'),
        )
        .key;
  }

  @override
  String toSql(ActivityEvent value) => _map[value]!;
}

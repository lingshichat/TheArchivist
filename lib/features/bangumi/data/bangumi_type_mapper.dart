import '../../../shared/data/app_database.dart';

abstract final class BangumiTypeMapper {
  static const List<int> supportedSubjectTypes = <int>[1, 2, 4, 6];

  static MediaType toMediaType(int subjectType, {int? totalEpisodes}) {
    switch (subjectType) {
      case 1:
        return MediaType.book;
      case 2:
        return MediaType.tv;
      case 4:
        return MediaType.game;
      case 6:
        return (totalEpisodes ?? 0) > 1 ? MediaType.tv : MediaType.movie;
      default:
        throw ArgumentError.value(
          subjectType,
          'subjectType',
          'Unsupported Bangumi subject type.',
        );
    }
  }

  static int toSubjectType(MediaType mediaType, {int? totalEpisodes}) {
    switch (mediaType) {
      case MediaType.book:
        return 1;
      case MediaType.tv:
        return 2;
      case MediaType.game:
        return 4;
      case MediaType.movie:
        return (totalEpisodes ?? 0) > 1 ? 2 : 6;
    }
  }

  static UnifiedStatus toUnifiedStatus(int collectionType) {
    switch (collectionType) {
      case 1:
        return UnifiedStatus.wishlist;
      case 2:
        return UnifiedStatus.inProgress;
      case 3:
        return UnifiedStatus.done;
      case 4:
        return UnifiedStatus.onHold;
      case 5:
        return UnifiedStatus.dropped;
      default:
        throw ArgumentError.value(
          collectionType,
          'collectionType',
          'Unsupported Bangumi collection type.',
        );
    }
  }

  static int toCollectionType(UnifiedStatus status) {
    switch (status) {
      case UnifiedStatus.wishlist:
        return 1;
      case UnifiedStatus.inProgress:
        return 2;
      case UnifiedStatus.done:
        return 3;
      case UnifiedStatus.onHold:
        return 4;
      case UnifiedStatus.dropped:
        return 5;
    }
  }
}

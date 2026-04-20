import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/local_view_adapters.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/widgets/poster_view_data.dart';

enum LibraryMediaType {
  movies('Movies'),
  books('Books'),
  games('Games');

  const LibraryMediaType(this.label);

  final String label;
}

enum LibraryStatusFilter {
  all('All', null),
  wishlist('Wishlist', UnifiedStatus.wishlist),
  inProgress('In Progress', UnifiedStatus.inProgress),
  completed('Completed', UnifiedStatus.done),
  onHold('On Hold', UnifiedStatus.onHold),
  dropped('Dropped', UnifiedStatus.dropped);

  const LibraryStatusFilter(this.label, this.status);

  final String label;
  final UnifiedStatus? status;

  String? get storageValue => status?.name;
}

enum LibrarySortOption {
  recent('Recent', 'updatedAt', true),
  title('Title', 'title', false),
  year('Year', 'releaseDate', true);

  const LibrarySortOption(this.label, this.sortBy, this.descending);

  final String label;
  final String sortBy;
  final bool descending;
}

class LibraryHeaderViewData {
  const LibraryHeaderViewData({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class LibraryQuery {
  const LibraryQuery({
    required this.mediaType,
    required this.statusFilter,
    required this.sortOption,
  });

  final LibraryMediaType mediaType;
  final LibraryStatusFilter statusFilter;
  final LibrarySortOption sortOption;

  @override
  bool operator ==(Object other) {
    return other is LibraryQuery &&
        other.mediaType == mediaType &&
        other.statusFilter == statusFilter &&
        other.sortOption == sortOption;
  }

  @override
  int get hashCode => Object.hash(mediaType, statusFilter, sortOption);
}

final libraryHeaderProvider = StreamProvider<LibraryHeaderViewData>((ref) {
  final mediaRepository = ref.watch(mediaRepositoryProvider);

  return mediaRepository.watchLibrary().map((items) {
    final count = items.length;
    final noun = count == 1 ? 'item' : 'items';

    return LibraryHeaderViewData(
      title: 'Welcome back, Elias.',
      subtitle: 'Managing $count $noun across your personal archive.',
    );
  });
});

final libraryItemsProvider =
    StreamProvider.family<List<PosterViewData>, LibraryQuery>((ref, query) {
      final mediaRepository = ref.watch(mediaRepositoryProvider);

      return mediaRepository
          .watchLibrary(
            types: _typesFor(query.mediaType),
            status: query.statusFilter.storageValue,
            sortBy: query.sortOption.sortBy,
            descending: query.sortOption.descending,
          )
          .map(
            (items) => items
                .map((item) => LocalViewAdapters.toPosterView(item))
                .toList(),
          );
    });

List<MediaType> _typesFor(LibraryMediaType type) {
  switch (type) {
    case LibraryMediaType.movies:
      return const <MediaType>[MediaType.movie, MediaType.tv];
    case LibraryMediaType.books:
      return const <MediaType>[MediaType.book];
    case LibraryMediaType.games:
      return const <MediaType>[MediaType.game];
  }
}

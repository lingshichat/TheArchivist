import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/daos/media_dao.dart';
import '../../../shared/data/local_view_adapters.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/data/stream_combine.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/category_view_data.dart';
import '../../../shared/widgets/poster_view_data.dart';

class HomeViewData {
  const HomeViewData({
    required this.continuing,
    required this.recentlyAdded,
    required this.recentlyFinished,
    required this.categories,
  });

  final List<PosterViewData> continuing;
  final List<PosterViewData> recentlyAdded;
  final List<PosterViewData> recentlyFinished;
  final List<CategoryViewData> categories;
}

final homeViewDataProvider = StreamProvider<HomeViewData>((ref) {
  final mediaRepository = ref.watch(mediaRepositoryProvider);

  return combineLatest4(
    mediaRepository.watchContinuing(limit: 5),
    mediaRepository.watchRecentlyAdded(limit: 8),
    mediaRepository.watchRecentlyFinished(limit: 6),
    mediaRepository.watchLibrary(),
    (
      List<MediaItemWithUserEntry> continuing,
      List<MediaItemWithUserEntry> recentlyAdded,
      List<MediaItemWithUserEntry> recentlyFinished,
      List<MediaItemWithUserEntry> libraryItems,
    ) {
      return HomeViewData(
        continuing: continuing
            .map(
              (item) => LocalViewAdapters.toPosterView(
                item,
                subtitleOverride: item.progressEntry == null
                    ? item.mediaItem.subtitle
                    : LocalViewAdapters.buildProgressSummary(
                        item.mediaItem,
                        item.progressEntry,
                      ),
              ),
            )
            .toList(),
        recentlyAdded: recentlyAdded
            .map((item) => LocalViewAdapters.toPosterView(item))
            .toList(),
        recentlyFinished: recentlyFinished
            .map((item) => LocalViewAdapters.toPosterView(item))
            .toList(),
        categories: _buildCategories(libraryItems),
      );
    },
  );
});

List<CategoryViewData> _buildCategories(
  List<MediaItemWithUserEntry> libraryItems,
) {
  var movieCount = 0;
  var bookCount = 0;
  var gameCount = 0;

  for (final item in libraryItems) {
    switch (item.mediaItem.mediaType) {
      case MediaType.movie:
      case MediaType.tv:
        movieCount += 1;
        break;
      case MediaType.book:
        bookCount += 1;
        break;
      case MediaType.game:
        gameCount += 1;
        break;
    }
  }

  return <CategoryViewData>[
    LocalViewAdapters.buildCategory(
      label: 'Movies & TV',
      count: movieCount,
      icon: Icons.movie_outlined,
      accentColor: AppColors.accent,
    ),
    LocalViewAdapters.buildCategory(
      label: 'Books',
      count: bookCount,
      icon: Icons.menu_book_rounded,
      accentColor: const Color(0xFF4A6552),
    ),
    LocalViewAdapters.buildCategory(
      label: 'Games',
      count: gameCount,
      icon: Icons.sports_esports_outlined,
      accentColor: AppColors.secondary,
    ),
  ];
}

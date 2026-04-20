import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/demo/demo_data.dart';
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

abstract class HomeViewDataSource {
  HomeViewData load();
}

class DemoHomeViewDataSource implements HomeViewDataSource {
  const DemoHomeViewDataSource();

  @override
  HomeViewData load() {
    return HomeViewData(
      continuing: DemoData.continuingItems.map((e) => e.toPosterView()).toList(),
      recentlyAdded:
          DemoData.recentlyAddedItems.map((e) => e.toPosterView()).toList(),
      recentlyFinished:
          DemoData.recentlyFinishedItems.map((e) => e.toPosterView()).toList(),
      categories:
          DemoData.mediaCategories.map((e) => e.toCategoryView()).toList(),
    );
  }
}

final homeViewDataSourceProvider = Provider<HomeViewDataSource>((ref) {
  return const DemoHomeViewDataSource();
});

final homeViewDataProvider = Provider<HomeViewData>((ref) {
  return ref.watch(homeViewDataSourceProvider).load();
});

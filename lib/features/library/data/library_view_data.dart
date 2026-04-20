import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/demo/demo_data.dart';
import '../../../shared/widgets/poster_view_data.dart';

enum LibraryMediaType {
  movies('Movies'),
  books('Books'),
  games('Games');

  const LibraryMediaType(this.label);

  final String label;
}

class LibraryHeaderViewData {
  const LibraryHeaderViewData({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

abstract class LibraryViewDataSource {
  LibraryHeaderViewData loadHeader();
  List<PosterViewData> itemsFor(LibraryMediaType type);
}

class DemoLibraryViewDataSource implements LibraryViewDataSource {
  const DemoLibraryViewDataSource();

  @override
  LibraryHeaderViewData loadHeader() {
    return const LibraryHeaderViewData(
      title: 'Welcome back, Elias.',
      subtitle: 'Managing 1,248 items across your personal archive.',
    );
  }

  @override
  List<PosterViewData> itemsFor(LibraryMediaType type) {
    switch (type) {
      case LibraryMediaType.movies:
        return DemoData.libraryItems.map((e) => e.toPosterView()).toList();
      case LibraryMediaType.books:
      case LibraryMediaType.games:
        return const [];
    }
  }
}

final libraryViewDataSourceProvider = Provider<LibraryViewDataSource>((ref) {
  return const DemoLibraryViewDataSource();
});

final libraryHeaderProvider = Provider<LibraryHeaderViewData>((ref) {
  return ref.watch(libraryViewDataSourceProvider).loadHeader();
});

final libraryItemsProvider =
    Provider.family<List<PosterViewData>, LibraryMediaType>((ref, type) {
      return ref.watch(libraryViewDataSourceProvider).itemsFor(type);
    });

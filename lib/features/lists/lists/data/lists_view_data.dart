import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/app_database.dart';
import '../../../shared/data/providers.dart';
import '../../../shared/data/repositories/shelf_repository.dart';
import '../../../shared/widgets/poster_view_data.dart';

class ShelfListCardViewData {
  const ShelfListCardViewData({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int itemCount;
  final DateTime createdAt;
}

class ShelfDetailViewData {
  const ShelfDetailViewData({
    required this.id,
    required this.name,
    required this.items,
    required this.itemCount,
  });

  final String id;
  final String name;
  final List<PosterViewData> items;
  final int itemCount;
}

final shelfListCenterProvider = StreamProvider<List<ShelfListCardViewData>>(
  (ref) {
    final shelfRepository = ref.watch(shelfRepositoryProvider);

    return shelfRepository.watchUserShelves().asyncMap((shelves) async {
      final result = <ShelfListCardViewData>[];

      for (final shelf in shelves) {
        final count = await shelfRepository.countShelfItems(shelf.id);
        result.add(
          ShelfListCardViewData(
            id: shelf.id,
            name: shelf.name,
            itemCount: count,
            createdAt: shelf.createdAt,
          ),
        );
      }

      return result;
    });
  },
);

class ShelfDetailQuery {
  const ShelfDetailQuery({required this.shelfId, required this.sortBy});

  final String shelfId;
  final ShelfSortOption sortBy;

  @override
  bool operator ==(Object other) {
    return other is ShelfDetailQuery &&
        other.shelfId == shelfId &&
        other.sortBy == sortBy;
  }

  @override
  int get hashCode => Object.hash(shelfId, sortBy);
}

final shelfDetailProvider =
    StreamProvider.family<ShelfDetailViewData, ShelfDetailQuery>(
  (ref, query) {
    final shelfRepository = ref.watch(shelfRepositoryProvider);

    return shelfRepository.watchUserShelves().asyncExpand((shelves) async* {
      final shelf = shelves.where((s) => s.id == query.shelfId).firstOrNull;
      if (shelf == null) {
        yield* const Stream<ShelfDetailViewData>.empty();
        return;
      }

      await for (final items in shelfRepository.watchShelfMediaItems(
        query.shelfId,
        sortBy: query.sortBy,
      )) {
        final viewItems = items
            .map(
              (item) => PosterViewData(
                id: item.id,
                title: item.title,
                mediaLabel: _mediaTypeLabel(item.mediaType),
                posterColor: _paletteFor(item.mediaType, item.title).background,
                posterAccentColor:
                    _paletteFor(item.mediaType, item.title).foreground,
                posterUrl: item.posterUrl,
                subtitle: item.subtitle,
                year: _yearLabel(item.releaseDate),
              ),
            )
            .toList();

        yield ShelfDetailViewData(
          id: shelf.id,
          name: shelf.name,
          items: viewItems,
          itemCount: viewItems.length,
        );
      }
    });
  },
);

String _mediaTypeLabel(MediaType type) {
  switch (type) {
    case MediaType.movie:
      return 'Movie';
    case MediaType.tv:
      return 'TV';
    case MediaType.book:
      return 'Book';
    case MediaType.game:
      return 'Game';
  }
}

String? _yearLabel(DateTime? date) {
  if (date == null) return null;
  return date.year.toString();
}

Palette _paletteFor(MediaType type, String title) {
  final hash = title.hashCode.abs();
  final hue = (hash % 360).toDouble();

  switch (type) {
    case MediaType.movie:
    case MediaType.tv:
      return Palette(
        background: HSLColor.fromAHSL(1, hue, 0.25, 0.88).toColor(),
        foreground: HSLColor.fromAHSL(1, hue, 0.45, 0.35).toColor(),
      );
    case MediaType.book:
      return Palette(
        background: HSLColor.fromAHSL(1, (hue + 60) % 360, 0.22, 0.90).toColor(),
        foreground: HSLColor.fromAHSL(1, (hue + 60) % 360, 0.40, 0.32).toColor(),
      );
    case MediaType.game:
      return Palette(
        background: HSLColor.fromAHSL(1, (hue + 120) % 360, 0.28, 0.87).toColor(),
        foreground: HSLColor.fromAHSL(1, (hue + 120) % 360, 0.42, 0.33).toColor(),
      );
  }
}

class Palette {
  const Palette({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

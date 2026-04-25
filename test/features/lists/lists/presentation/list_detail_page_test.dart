import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/lists/data/lists_view_data.dart';
import 'package:record_anywhere/features/lists/presentation/list_detail_page.dart';
import 'package:record_anywhere/shared/data/repositories/shelf_repository.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';
import 'package:record_anywhere/shared/widgets/poster_view_data.dart';

void main() {
  testWidgets('list detail page shows empty state when list has no items',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const query = ShelfDetailQuery(shelfId: 's1', sortBy: ShelfSortOption.position);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shelfDetailProvider(query).overrideWith(
            (ref) => Stream.value(
              const ShelfDetailViewData(
                id: 's1',
                name: 'Watchlist',
                items: [],
                itemCount: 0,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ListDetailPage(listId: 's1')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('This list is empty'), findsOneWidget);
    expect(find.text('OPEN LIBRARY'), findsOneWidget);  });

  testWidgets('list detail page shows poster items when list has content',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const query = ShelfDetailQuery(shelfId: 's1', sortBy: ShelfSortOption.position);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shelfDetailProvider(query).overrideWith(
            (ref) => Stream.value(
              const ShelfDetailViewData(
                id: 's1',
                name: 'Watchlist',
                items: [
                  PosterViewData(
                    id: 'item-1',
                    title: 'Arrival',
                    mediaLabel: 'Movie',
                    posterColor: AppColors.accent,
                    posterAccentColor: AppColors.accentStrong,
                    year: '2016',
                  ),
                  PosterViewData(
                    id: 'item-2',
                    title: 'Inception',
                    mediaLabel: 'Movie',
                    posterColor: AppColors.accent,
                    posterAccentColor: AppColors.accentStrong,
                    year: '2010',
                  ),
                ],
                itemCount: 2,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ListDetailPage(listId: 's1')),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Inception'), findsOneWidget);
    expect(find.text('This list is empty'), findsNothing);
  });
}

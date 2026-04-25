import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/lists/data/lists_view_data.dart';
import 'package:record_anywhere/features/lists/presentation/lists_center_page.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';

void main() {
  testWidgets('lists center page shows empty state when no shelves exist',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shelfListCenterProvider.overrideWith(
            (ref) => Stream.value(<ShelfListCardViewData>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ListsCenterPage()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('No lists yet'), findsOneWidget);
    expect(find.text('Create List'), findsOneWidget);
  });

  testWidgets('lists center page shows shelf cards and correct count',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shelfListCenterProvider.overrideWith(
            (ref) => Stream.value(<ShelfListCardViewData>[
              ShelfListCardViewData(
                id: 's1',
                name: 'Watchlist',
                itemCount: 5,
                createdAt: _jan1,
              ),
              ShelfListCardViewData(
                id: 's2',
                name: 'Favorites',
                itemCount: 12,
                createdAt: _jan1,
              ),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ListsCenterPage()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('2 custom lists'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('No lists yet'), findsNothing);
  });
}

final _jan1 = DateTime(2026, 1, 1);

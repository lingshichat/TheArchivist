import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/library/data/library_view_data.dart';
import 'package:record_anywhere/features/library/presentation/library_page.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';
import 'package:record_anywhere/shared/widgets/poster_view_data.dart';

void main() {
  testWidgets(
    'library page keeps add entry button visible and removes load more control',
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
            libraryHeaderProvider.overrideWith(
              (ref) => Stream.value(
                const LibraryHeaderViewData(
                  title: 'Welcome back, Elias.',
                  subtitle: 'Managing 1 item across your personal archive.',
                ),
              ),
            ),
            libraryItemsProvider.overrideWith(
              (ref, query) => Stream.value(const <PosterViewData>[
                PosterViewData(
                  id: 'item-1',
                  title: 'Arrival',
                  mediaLabel: 'Movie',
                  posterColor: AppColors.accent,
                  posterAccentColor: AppColors.accentStrong,
                  year: '2016',
                  statusLabel: 'Done',
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: LibraryPage()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Add Entry'), findsOneWidget);
      expect(find.text('LOAD MORE ENTRIES'), findsNothing);
      expect(find.text('Welcome back, Elias.'), findsOneWidget);
    },
  );
}

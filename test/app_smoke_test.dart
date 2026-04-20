import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/home/data/home_view_data.dart';
import 'package:record_anywhere/features/home/presentation/home_page.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';

void main() {
  testWidgets('home page renders archive sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeViewDataProvider.overrideWith(
            (ref) => Stream.value(
              const HomeViewData(
                continuing: [],
                recentlyAdded: [],
                recentlyFinished: [],
                categories: [],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Continuing'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';
import 'package:record_anywhere/shared/widgets/local_feedback.dart';

void main() {
  testWidgets('local feedback with action still auto dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showLocalFeedback(
                      context,
                      'Saved locally.',
                      actionLabel: 'View details',
                      onActionTap: () {},
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.persist, isFalse);
    expect(find.text('Saved locally.'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Saved locally.'), findsNothing);
  });
}

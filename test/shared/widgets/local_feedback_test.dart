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
    expect(snackBar.backgroundColor, Colors.transparent);
    expect(find.text('Saved locally.'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    final successIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Icon),
      ).first,
    );
    expect(successIcon.icon, Icons.check_circle);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Saved locally.'), findsNothing);
  });

  testWidgets('local feedback can render error tone', (tester) async {
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
                      'Could not save the entry.',
                      tone: LocalFeedbackTone.error,
                    );
                  },
                  child: const Text('Show error'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Show error'));
    await tester.pump();

    expect(find.text('Could not save the entry.'), findsOneWidget);
    final errorIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Icon),
      ).first,
    );
    expect(errorIcon.icon, Icons.cancel);
  });
}

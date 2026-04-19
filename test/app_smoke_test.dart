import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/app/app.dart';

void main() {
  testWidgets('home shell renders stitch-inspired sections', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RecordAnywhereApp()));
    await tester.pumpAndSettle();

    expect(find.text('Continuing'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/add/data/bangumi_search_providers.dart';
import 'package:record_anywhere/features/add/presentation/bangumi_search_result_card.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_models.dart';
import 'package:record_anywhere/shared/data/app_database.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';

void main() {
  Widget buildHost(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  BangumiSubjectDto buildSubject() {
    return const BangumiSubjectDto(
      id: 42,
      type: 2,
      name: 'Cowboy Bebop',
      nameCn: '星际牛仔',
      summary: 'A crew of bounty hunters travels across the solar system.',
      date: '1998-04-03',
    );
  }

  testWidgets('search result card shows view and add for remote result', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHost(
        BangumiSearchResultCard(
          subject: buildSubject(),
          isBusy: false,
          onViewTap: () {},
          onAddTap: () {},
        ),
      ),
    );

    expect(find.text('View'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('ADDED'), findsNothing);
  });

  testWidgets('search result card keeps view for locally added result', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHost(
        BangumiSearchResultCard(
          subject: buildSubject(),
          localMatch: const BangumiLocalMatch(
            mediaId: 'local-1',
            status: UnifiedStatus.done,
            title: '星际牛仔',
          ),
          isBusy: false,
          onViewTap: () {},
          onAddTap: () {},
        ),
      ),
    );

    expect(find.text('View'), findsOneWidget);
    expect(find.text('ADDED'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
  });
}

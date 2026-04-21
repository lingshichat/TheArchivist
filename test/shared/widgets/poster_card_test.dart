import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';
import 'package:record_anywhere/shared/widgets/poster_card.dart';
import 'package:record_anywhere/shared/widgets/poster_view_data.dart';

void main() {
  testWidgets('finished overlay subtitle does not force italic style', (
    tester,
  ) async {
    const subtitle = '凉宫春日的忧郁';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: PosterCard(
                variant: PosterCardVariant.finishedOverlay,
                item: const PosterViewData(
                  id: 'item-1',
                  title: '凉宫春日の憂鬱',
                  subtitle: subtitle,
                  mediaLabel: 'Book',
                  posterColor: AppColors.accent,
                  posterAccentColor: AppColors.accentStrong,
                  statusLabel: 'Completed',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final subtitleText = tester.widget<Text>(find.text(subtitle));

    expect(subtitleText.style?.fontStyle, isNot(FontStyle.italic));
    expect(subtitleText.style?.color, AppColors.onSurfaceVariant);
  });
}

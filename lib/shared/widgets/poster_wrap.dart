import 'package:flutter/material.dart';

import '../demo/demo_data.dart';
import 'poster_card.dart';

class PosterWrap extends StatelessWidget {
  const PosterWrap({
    super.key,
    required this.items,
    required this.minColumns,
    required this.maxColumns,
    this.onItemTap,
    this.minTileWidth = 120,
    this.horizontalSpacing = 20,
    this.verticalSpacing = 32,
    this.showSubtitle = false,
    this.showFooter = false,
  });

  final List<DemoMediaItem> items;
  final int minColumns;
  final int maxColumns;
  final VoidCallback? onItemTap;
  final double minTileWidth;
  final double horizontalSpacing;
  final double verticalSpacing;
  final bool showSubtitle;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int estimatedColumns =
            ((constraints.maxWidth + horizontalSpacing) /
                    (minTileWidth + horizontalSpacing))
                .floor();
        final int columns;

        if (estimatedColumns < minColumns) {
          columns = minColumns;
        } else if (estimatedColumns > maxColumns) {
          columns = maxColumns;
        } else {
          columns = estimatedColumns;
        }

        final double totalSpacing = (columns - 1) * horizontalSpacing;
        final double itemWidth =
            (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: horizontalSpacing,
          runSpacing: verticalSpacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: PosterCard(
                    item: item,
                    onTap: onItemTap,
                    showSubtitle: showSubtitle,
                    showFooter: showFooter,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

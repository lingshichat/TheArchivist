import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + _controller.value * 0.25,
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 14,
            width: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.itemCount = 12,
    this.minColumns = 4,
    this.maxColumns = 7,
    this.minTileWidth = 150,
    this.horizontalSpacing = 24,
    this.verticalSpacing = 40,
  });

  final int itemCount;
  final int minColumns;
  final int maxColumns;
  final double minTileWidth;
  final double horizontalSpacing;
  final double verticalSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int estimatedColumns =
            ((constraints.maxWidth + horizontalSpacing) /
                    (minTileWidth + horizontalSpacing))
                .floor();
        final int columns = estimatedColumns.clamp(minColumns, maxColumns);
        final double totalSpacing = (columns - 1) * horizontalSpacing;
        final double itemWidth =
            (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: horizontalSpacing,
          runSpacing: verticalSpacing,
          children: List.generate(
            itemCount,
            (index) => SizedBox(
              width: itemWidth,
              child: const SkeletonCard(),
            ),
          ),
        );
      },
    );
  }
}

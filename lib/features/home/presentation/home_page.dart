import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/demo/demo_data.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/poster_art.dart';
import '../../../shared/widgets/section_header.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Continuing',
            actionLabel: 'View All',
            onActionTap: () => context.go(AppRoutes.library),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ResponsiveGrid(
            items: DemoData.continuingItems,
            minColumns: 2,
            maxColumns: 5,
            minTileWidth: 170,
            horizontalSpacing: AppSpacing.xxl,
            verticalSpacing: AppSpacing.xxl,
            itemBuilder: (item) => _HomePosterTile(
              item: item,
              label: item.mediaLabel,
              onTap: () => context.go(AppRoutes.detail),
            ),
          ),
          const SizedBox(height: 64),
          SectionHeader(
            title: 'Recently Added',
            actionLabel: 'View All',
            onActionTap: () => context.go(AppRoutes.library),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ResponsiveGrid(
            items: DemoData.recentlyAddedItems,
            minColumns: 3,
            maxColumns: 8,
            minTileWidth: 112,
            horizontalSpacing: AppSpacing.xl,
            verticalSpacing: AppSpacing.xl,
            itemBuilder: (item) => _HomePosterTile(
              item: item,
              label: item.mediaLabel,
              compact: true,
              onTap: () => context.go(AppRoutes.detail),
            ),
          ),
          const SizedBox(height: 64),
          SectionHeader(
            title: 'Recently Finished',
            actionLabel: 'Archive',
            onActionTap: () => context.go(AppRoutes.library),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ResponsiveGrid(
            items: DemoData.recentlyFinishedItems,
            minColumns: 2,
            maxColumns: 6,
            minTileWidth: 140,
            horizontalSpacing: AppSpacing.xxl,
            verticalSpacing: AppSpacing.xxl,
            itemBuilder: (item) => _FinishedPosterTile(
              item: item,
              onTap: () => context.go(AppRoutes.detail),
            ),
          ),
          const SizedBox(height: 64),
          const SectionHeader(title: 'Categories'),
          const SizedBox(height: AppSpacing.xl),
          const _CategoryGrid(),
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.items,
    required this.minColumns,
    required this.maxColumns,
    required this.minTileWidth,
    required this.horizontalSpacing,
    required this.verticalSpacing,
    required this.itemBuilder,
  });

  final List<DemoMediaItem> items;
  final int minColumns;
  final int maxColumns;
  final double minTileWidth;
  final double horizontalSpacing;
  final double verticalSpacing;
  final Widget Function(DemoMediaItem item) itemBuilder;

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
          children: items
              .map(
                (item) => SizedBox(width: itemWidth, child: itemBuilder(item)),
              )
              .toList(),
        );
      },
    );
  }
}

class _HomePosterTile extends StatelessWidget {
  const _HomePosterTile({
    required this.item,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final DemoMediaItem item;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.container),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadii.container),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                child: PosterArt(item: item),
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: compact ? AppColors.subtleText : AppColors.accentStrong,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: compact
                  ? theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    )
                  : theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedPosterTile extends StatelessWidget {
  const _FinishedPosterTile({required this.item, required this.onTap});

  final DemoMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.container),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadii.container),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      ),
                      child: PosterArt(item: item, muted: true),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          item.statusLabel.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.accentForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth;

        if (constraints.maxWidth >= 1080) {
          cardWidth = (constraints.maxWidth - (AppSpacing.xl * 2)) / 3;
        } else if (constraints.maxWidth >= 700) {
          cardWidth = (constraints.maxWidth - AppSpacing.xl) / 2;
        } else {
          cardWidth = constraints.maxWidth;
        }

        return Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.xl,
          children: DemoData.mediaCategories
              .map(
                (category) => Container(
                  width: cardWidth,
                  height: 184,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadii.floating),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -12,
                        bottom: -20,
                        child: Icon(
                          category.icon,
                          size: 118,
                          color: category.accentColor.withValues(alpha: 0.12),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            category.icon,
                            color: AppColors.accent,
                            size: 28,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.label,
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                category.description,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

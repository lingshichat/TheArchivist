import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/demo/demo_data.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/poster_art.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
          Text('媒体库 / Library', style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Managing 1,248 items across your personal archive.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xxl),
          LayoutBuilder(
            builder: (context, constraints) {
              final Widget tabs = Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.sm,
                children: const [
                  _LibraryTab(label: 'Movies', isActive: true),
                  _LibraryTab(label: 'Books'),
                  _LibraryTab(label: 'Games'),
                ],
              );
              final Widget filters = Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: const [
                  _CompactFilter(label: 'Status', value: 'All'),
                  _CompactFilter(label: 'Sort', value: 'Recent'),
                ],
              );

              if (constraints.maxWidth >= 920) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: tabs),
                    filters,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tabs,
                  const SizedBox(height: AppSpacing.lg),
                  filters,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          _LibraryGrid(
            items: DemoData.libraryItems,
            minColumns: 4,
            maxColumns: 7,
            minTileWidth: 150,
            onItemTap: () => context.go(AppRoutes.detail),
          ),
          const SizedBox(height: 80),
          Center(
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Load More Entries'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryGrid extends StatelessWidget {
  const _LibraryGrid({
    required this.items,
    required this.minColumns,
    required this.maxColumns,
    required this.minTileWidth,
    required this.onItemTap,
  });

  final List<DemoMediaItem> items;
  final int minColumns;
  final int maxColumns;
  final double minTileWidth;
  final VoidCallback onItemTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double horizontalSpacing = 24;
        const double verticalSpacing = 40;
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
                (item) => SizedBox(
                  width: itemWidth,
                  child: _LibraryPosterTile(item: item, onTap: onItemTap),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LibraryPosterTile extends StatelessWidget {
  const _LibraryPosterTile({required this.item, required this.onTap});

  final DemoMediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _LibraryStatusPalette palette = _paletteFor(item.statusTone);

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
            const SizedBox(height: 12),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Text(
                    item.statusLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(item.year, style: theme.textTheme.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _LibraryStatusPalette _paletteFor(DemoStatusTone tone) {
    switch (tone) {
      case DemoStatusTone.primary:
        return const _LibraryStatusPalette(
          background: AppColors.accentContainer,
          foreground: AppColors.accentStrong,
        );
      case DemoStatusTone.tertiary:
        return const _LibraryStatusPalette(
          background: AppColors.tertiaryContainer,
          foreground: AppColors.onSurface,
        );
      case DemoStatusTone.muted:
        return const _LibraryStatusPalette(
          background: AppColors.surfaceContainerHigh,
          foreground: AppColors.subtleText,
        );
      case DemoStatusTone.secondary:
        return const _LibraryStatusPalette(
          background: AppColors.secondaryContainer,
          foreground: AppColors.onSurface,
        );
    }
  }
}

class _LibraryStatusPalette {
  const _LibraryStatusPalette({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({required this.label, this.isActive = false});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isActive ? AppColors.accent : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: isActive ? AppColors.accent : AppColors.subtleText,
        ),
      ),
    );
  }
}

class _CompactFilter extends StatelessWidget {
  const _CompactFilter({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.floating),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${label.toUpperCase()}:', style: theme.textTheme.labelMedium),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: AppColors.subtleText,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../demo/demo_data.dart';
import '../theme/app_theme.dart';
import 'poster_art.dart';

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    this.onTap,
    this.showSubtitle = false,
    this.showFooter = false,
  });

  final DemoMediaItem item;
  final VoidCallback? onTap;
  final bool showSubtitle;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _StatusPalette statusPalette = _statusPaletteFor(item.statusTone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.container),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.container),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.22),
                ),
              ),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: PosterArt(item: item),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          item.mediaLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.subtleText.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (showFooter) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusPalette.background,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Text(
                  item.statusLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusPalette.foreground,
                  ),
                ),
              ),
              const Spacer(),
              Text(item.year, style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ],
    );
  }

  _StatusPalette _statusPaletteFor(DemoStatusTone tone) {
    switch (tone) {
      case DemoStatusTone.primary:
        return const _StatusPalette(
          background: AppColors.accentContainer,
          foreground: AppColors.accentStrong,
        );
      case DemoStatusTone.tertiary:
        return const _StatusPalette(
          background: AppColors.tertiaryContainer,
          foreground: AppColors.onSurface,
        );
      case DemoStatusTone.muted:
        return const _StatusPalette(
          background: AppColors.surfaceContainerHigh,
          foreground: AppColors.subtleText,
        );
      case DemoStatusTone.secondary:
        return const _StatusPalette(
          background: AppColors.secondaryContainer,
          foreground: AppColors.onSurface,
        );
    }
  }
}

class _StatusPalette {
  const _StatusPalette({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'poster_art.dart';
import 'poster_view_data.dart';

enum PosterCardVariant {
  continuing,
  compact,
  finishedOverlay,
  libraryFooter,
}

class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.item,
    this.variant = PosterCardVariant.continuing,
    this.onTap,
  });

  final PosterViewData item;
  final PosterCardVariant variant;
  final VoidCallback? onTap;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool muted = widget.variant == PosterCardVariant.finishedOverlay;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        offset: _hovered ? const Offset(0, -0.015) : Offset.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? AppColors.surfaceContainerLowest
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      border: Border.all(
                        color: _hovered
                            ? AppColors.outlineVariant.withValues(alpha: 0.22)
                            : Colors.transparent,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: PosterArt(item: widget.item, muted: muted),
                        ),
                        if (widget.variant ==
                                PosterCardVariant.finishedOverlay &&
                            widget.item.statusLabel != null)
                          Positioned.fill(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.92,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                                child: Text(
                                  widget.item.statusLabel!.toUpperCase(),
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
                ),
                SizedBox(
                  height: widget.variant == PosterCardVariant.compact ? 12 : 16,
                ),
                _buildMeta(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(ThemeData theme) {
    switch (widget.variant) {
      case PosterCardVariant.continuing:
        return _continuingMeta(theme);
      case PosterCardVariant.compact:
        return _compactMeta(theme);
      case PosterCardVariant.finishedOverlay:
        return _finishedMeta(theme);
      case PosterCardVariant.libraryFooter:
        return _libraryMeta(theme);
    }
  }

  Widget _continuingMeta(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.mediaLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.accentStrong,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.item.subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            widget.item.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _compactMeta(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.mediaLabel.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.subtleText,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _finishedMeta(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.item.subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.item.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _libraryMeta(ThemeData theme) {
    final _PosterStatusPalette palette = _paletteFor(widget.item.statusTone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.title,
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
            if (widget.item.statusLabel != null)
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
                  widget.item.statusLabel!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.foreground,
                  ),
                ),
              ),
            if (widget.item.statusLabel != null && widget.item.year != null)
              const SizedBox(width: AppSpacing.sm),
            if (widget.item.year != null)
              Text(widget.item.year!, style: theme.textTheme.labelMedium),
          ],
        ),
      ],
    );
  }
}

_PosterStatusPalette _paletteFor(PosterStatusTone tone) {
  switch (tone) {
    case PosterStatusTone.primary:
      return const _PosterStatusPalette(
        background: AppColors.accentContainer,
        foreground: AppColors.accentStrong,
      );
    case PosterStatusTone.tertiary:
      return const _PosterStatusPalette(
        background: AppColors.tertiaryContainer,
        foreground: AppColors.onSurface,
      );
    case PosterStatusTone.muted:
      return const _PosterStatusPalette(
        background: AppColors.surfaceContainerHigh,
        foreground: AppColors.subtleText,
      );
    case PosterStatusTone.secondary:
      return const _PosterStatusPalette(
        background: AppColors.secondaryContainer,
        foreground: AppColors.onSurface,
      );
  }
}

class _PosterStatusPalette {
  const _PosterStatusPalette({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

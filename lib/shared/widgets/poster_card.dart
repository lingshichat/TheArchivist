import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'poster_art.dart';
import 'poster_view_data.dart';

enum PosterCardVariant { continuing, compact, finishedOverlay, libraryFooter }

class PosterCard extends StatefulWidget {
  const PosterCard({
    super.key,
    required this.item,
    this.variant = PosterCardVariant.continuing,
    this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelection,
    this.showOrderControls = false,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  final PosterViewData item;
  final PosterCardVariant variant;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;
  final bool showOrderControls;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

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
            onTap:
                widget.selectionMode
                    ? widget.onToggleSelection
                    : widget.onTap,
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
                        color: widget.isSelected
                            ? AppColors.accent.withValues(alpha: 0.6)
                            : _hovered
                            ? AppColors.outlineVariant.withValues(alpha: 0.22)
                            : Colors.transparent,
                        width: widget.isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: PosterArt(item: widget.item, muted: muted),
                        ),
                        if (widget.selectionMode)
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: _SelectionIndicator(
                              isSelected: widget.isSelected,
                            ),
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
                if (widget.showOrderControls) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _OrderControls(
                    canMoveUp: widget.canMoveUp,
                    canMoveDown: widget.canMoveDown,
                    onMoveUp: widget.onMoveUp,
                    onMoveDown: widget.onMoveDown,
                  ),
                ],
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
          /*
           * ========================================================================
           * 步骤1：收紧完成区副标题样式
           * ========================================================================
           * 目标：
           *   1) 避免中文副标题在 Home 完成区出现过强的斜体感
           *   2) 保持副标题是弱化说明，而不是第二主标题
           */
          Text(
            widget.item.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceVariant,
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

class _OrderControls extends StatelessWidget {
  const _OrderControls({
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _IconButton(
          icon: Icons.arrow_upward_rounded,
          onTap: canMoveUp ? onMoveUp : null,
        ),
        const SizedBox(width: AppSpacing.xs),
        _IconButton(
          icon: Icons.arrow_downward_rounded,
          onTap: canMoveDown ? onMoveDown : null,
        ),
      ],
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.accent
                : AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(
          color:
              isSelected
                  ? AppColors.accent
                  : AppColors.outlineVariant.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child:
          isSelected
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
    );
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color:
                  _hovered
                      ? AppColors.surfaceContainerHighest.withValues(alpha: 0.5)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color:
                  widget.onTap != null
                      ? AppColors.onSurfaceVariant
                      : AppColors.subtleText.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

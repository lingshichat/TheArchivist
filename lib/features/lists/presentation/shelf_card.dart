import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/lists_view_data.dart';

class ShelfCard extends StatefulWidget {
  const ShelfCard({
    super.key,
    required this.data,
    this.onEdit,
    this.onDelete,
  });

  final ShelfListCardViewData data;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<ShelfCard> createState() => _ShelfCardState();
}

class _ShelfCardState extends State<ShelfCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.listDetailFor(widget.data.id)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color:
                _hovered
                    ? AppColors.surfaceContainer
                    : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.container),
            border: Border.all(
              color:
                  _hovered
                      ? AppColors.outlineVariant.withValues(alpha: 0.25)
                      : AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
            boxShadow:
                _hovered
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                    : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.container),
            child: Stack(
              children: [
                // Left accent bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _hovered ? 4 : 3,
                    color:
                        _hovered
                            ? AppColors.accent
                            : AppColors.accent.withValues(alpha: 0.35),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShelfAvatar(name: widget.data.name),
                          const Spacer(),
                          if (_hovered)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _IconButton(
                                  icon: Icons.edit_outlined,
                                  onTap: widget.onEdit,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                _IconButton(
                                  icon: Icons.delete_outline_rounded,
                                  onTap: widget.onDelete,
                                ),
                              ],
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        widget.data.name,
                        style: AppTextStyles.panelTitle(theme).copyWith(
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _itemCountLabel(widget.data.itemCount).toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Hover arrow indicator
                if (_hovered)
                  Positioned(
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.accent.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _itemCountLabel(int count) {
    return '$count ${count == 1 ? 'item' : 'items'}';
  }
}

class _ShelfAvatar extends StatelessWidget {
  const _ShelfAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hue = (name.hashCode.abs() % 360).toDouble();
    // Dark-theme compatible: lower lightness, moderate saturation
    final background = HSLColor.fromAHSL(1, hue, 0.3, 0.22).toColor();
    final foreground = HSLColor.fromAHSL(1, hue, 0.4, 0.72).toColor();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
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
                      ? AppColors.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              widget.icon,
              size: 18,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

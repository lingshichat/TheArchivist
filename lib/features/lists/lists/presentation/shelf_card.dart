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

  void _onEnter(PointerEvent event) => setState(() => _hovered = true);
  void _onExit(PointerEvent event) => setState(() => _hovered = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(AppRoutes.listDetailFor(widget.data.id)),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color:
                  _hovered
                      ? AppColors.surfaceContainer
                      : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color:
                    _hovered
                        ? AppColors.outlineVariant.withValues(alpha: 0.25)
                        : AppColors.outlineVariant.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                            onTap: () {
                              widget.onEdit?.call();
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _IconButton(
                            icon: Icons.delete_outline_rounded,
                            onTap: () {
                              widget.onDelete?.call();
                            },
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  widget.data.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _itemCountLabel(widget.data.itemCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
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
    final background = HSLColor.fromAHSL(1, hue, 0.2, 0.88).toColor();
    final foreground = HSLColor.fromAHSL(1, hue, 0.4, 0.35).toColor();

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
  final VoidCallback onTap;

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
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

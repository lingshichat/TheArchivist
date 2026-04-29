import 'package:cached_network_image/cached_network_image.dart';
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
      child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: _hovered ? const Offset(0, -0.015) : Offset.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster area: 2:3 aspect ratio with 2×2 mosaic inside
              AspectRatio(
                aspectRatio: 2 / 3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(
                      color: _hovered
                          ? AppColors.outlineVariant.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                    boxShadow: _hovered
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.listDetailFor(widget.data.id)),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        child: Stack(
                          children: [
                            // 2×2 Poster Mosaic
                            Positioned.fill(
                              child: _PosterMosaic(
                                previewItems: widget.data.previewItems,
                                listName: widget.data.name,
                              ),
                            ),
                            // Hover actions: edit / delete
                            if (_hovered)
                              Positioned(
                                top: AppSpacing.sm,
                                right: AppSpacing.sm,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _CardIconButton(
                                      icon: Icons.edit_outlined,
                                      onTap: widget.onEdit,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    _CardIconButton(
                                      icon: Icons.delete_outline_rounded,
                                      onTap: widget.onDelete,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Info bar: list name + item count (aligned with libraryFooter)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data.name,
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
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppRadii.card),
                          ),
                          child: Text(
                            '${widget.data.itemCount} ${widget.data.itemCount == 1 ? 'item' : 'items'}'
                                .toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.subtleText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// 2×2 Poster Mosaic — 4 slots with poster thumbnails or fallback color blocks
// ---------------------------------------------------------------------------

class _PosterMosaic extends StatelessWidget {
  const _PosterMosaic({
    required this.previewItems,
    required this.listName,
  });

  final List<ShelfPreviewItem> previewItems;
  final String listName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _MosaicSlot(item: _itemAt(0), listName: listName, slotIndex: 0)),
              _SlotDivider(axis: Axis.vertical),
              Expanded(child: _MosaicSlot(item: _itemAt(1), listName: listName, slotIndex: 1)),
            ],
          ),
        ),
        _SlotDivider(axis: Axis.horizontal),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _MosaicSlot(item: _itemAt(2), listName: listName, slotIndex: 2)),
              _SlotDivider(axis: Axis.vertical),
              Expanded(child: _MosaicSlot(item: _itemAt(3), listName: listName, slotIndex: 3)),
            ],
          ),
        ),
      ],
    );
  }

  ShelfPreviewItem? _itemAt(int index) {
    return index < previewItems.length ? previewItems[index] : null;
  }
}

// Thin separator line between mosaic slots
class _SlotDivider extends StatelessWidget {
  const _SlotDivider({required this.axis});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: axis == Axis.vertical ? 1 : double.infinity,
      height: axis == Axis.horizontal ? 1 : double.infinity,
      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.8),
    );
  }
}

// Individual mosaic slot: poster image or fallback gradient
class _MosaicSlot extends StatelessWidget {
  const _MosaicSlot({
    required this.item,
    required this.listName,
    required this.slotIndex,
  });

  final ShelfPreviewItem? item;
  final String listName;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    if (item != null && item!.posterUrl != null && item!.posterUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: item!.posterUrl!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        memCacheWidth: 200,
        memCacheHeight: 300,
        placeholder: (context, url) => _FallbackGradient(listName: listName, slotIndex: slotIndex),
        errorWidget: (context, url, error) => _FallbackGradient(listName: listName, slotIndex: slotIndex),
      );
    }
    return _FallbackGradient(listName: listName, slotIndex: slotIndex);
  }
}

// Fallback gradient + geometric decorations (matches PosterArt style)
class _FallbackGradient extends StatelessWidget {
  const _FallbackGradient({required this.listName, required this.slotIndex});

  final String listName;
  final int slotIndex;

  @override
  Widget build(BuildContext context) {
    final hash = listName.hashCode.abs();
    final baseHue = (hash % 360).toDouble();
    // Offset hue per slot for subtle variation
    final hue = ((baseHue + slotIndex * 45) % 360).toDouble();

    final bg1 = HSLColor.fromAHSL(1, hue, 0.25, 0.14).toColor();
    final bg2 = HSLColor.fromAHSL(1, (hue + 35) % 360, 0.18, 0.10).toColor();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bg1, bg2],
            ),
          ),
        ),
        // Subtle geometric decoration (PosterArt-style)
        Positioned(
          left: -8,
          top: 8,
          child: Transform.rotate(
            angle: -0.25 + slotIndex * 0.1,
            child: Container(
              width: 28,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
        ),
        Positioned(
          right: -4,
          top: 10,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hover icon button
// ---------------------------------------------------------------------------

class _CardIconButton extends StatefulWidget {
  const _CardIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_CardIconButton> createState() => _CardIconButtonState();
}

class _CardIconButtonState extends State<_CardIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceContainerHighest.withValues(alpha: 0.85)
                : AppColors.surfaceContainerLowest.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

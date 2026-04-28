import 'package:flutter/material.dart';

import 'poster_card.dart';
import 'poster_view_data.dart';

class PosterWrap extends StatelessWidget {
  const PosterWrap({
    super.key,
    required this.items,
    required this.minColumns,
    required this.maxColumns,
    this.onItemTap,
    this.variant = PosterCardVariant.continuing,
    this.minTileWidth = 120,
    this.horizontalSpacing = 20,
    this.verticalSpacing = 32,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onToggleSelection,
    this.showOrderControls = false,
    this.onReorder,
  });

  final List<PosterViewData> items;
  final int minColumns;
  final int maxColumns;
  final ValueChanged<PosterViewData>? onItemTap;
  final PosterCardVariant variant;
  final double minTileWidth;
  final double horizontalSpacing;
  final double verticalSpacing;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<PosterViewData>? onToggleSelection;
  final bool showOrderControls;
  final ReorderCallback? onReorder;

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
              .asMap()
              .entries
              .map(
                (entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _StaggeredPosterItem(
                    index: index,
                    columns: columns,
                    child: SizedBox(
                      width: itemWidth,
                      child: PosterCard(
                        item: item,
                        variant: variant,
                        onTap:
                            onItemTap == null ? null : () => onItemTap!(item),
                        selectionMode: selectionMode,
                        isSelected: selectedIds.contains(item.id),
                        onToggleSelection:
                            onToggleSelection == null
                                ? null
                                : () => onToggleSelection!(item),
                        showOrderControls: showOrderControls,
                        canMoveUp: index > 0,
                        canMoveDown: index < items.length - 1,
                        onMoveUp:
                            onReorder == null || index == 0
                                ? null
                                : () => onReorder!(index, index - 1),
                        onMoveDown:
                            onReorder == null || index >= items.length - 1
                                ? null
                                : () => onReorder!(index, index + 1),
                      ),
                    ),
                  );
                },
              )
              .toList(),
        );
      },
    );
  }
}

class _StaggeredPosterItem extends StatefulWidget {
  const _StaggeredPosterItem({
    required this.index,
    required this.columns,
    required this.child,
  });

  final int index;
  final int columns;
  final Widget child;

  @override
  State<_StaggeredPosterItem> createState() => _StaggeredPosterItemState();
}

class _StaggeredPosterItemState extends State<_StaggeredPosterItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final row = widget.index ~/ widget.columns;
    final col = widget.index % widget.columns;
    final delayMs = (row * 60 + col * 40).clamp(0, 600);

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: FractionalTranslation(
            translation: Offset(0, 0.06 * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

typedef ReorderCallback = void Function(int oldIndex, int newIndex);

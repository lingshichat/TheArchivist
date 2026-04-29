import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/data/repositories/shelf_repository.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/poster_view_data.dart';
import '../../../shared/widgets/poster_wrap.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/lists_controller.dart';
import '../data/lists_view_data.dart';
import 'batch_action_bar.dart';

class ListDetailPage extends ConsumerStatefulWidget {
  const ListDetailPage({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends ConsumerState<ListDetailPage> {
  ShelfSortOption _sortBy = ShelfSortOption.position;

  bool _batchMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(shelfDetailProvider(
        ShelfDetailQuery(shelfId: widget.listId, sortBy: _sortBy),
      ));
    });
  }

  void _enterBatchMode() {
    setState(() {
      _batchMode = true;
      _selectedIds.clear();
    });
  }

  void _exitBatchMode() {
    setState(() {
      _batchMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _handleReorder(
    BuildContext context,
    List<PosterViewData> items,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return;

    final reordered = List<PosterViewData>.from(items);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    final orderedIds = reordered.map((e) => e.id).toList();

    ref.read(listsControllerProvider).reorderItems(widget.listId, orderedIds);
  }

  Future<void> _removeFromList() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Remove ${_selectedIds.length} ${_selectedIds.length == 1 ? 'item' : 'items'}?',
        body: 'These items will be removed from this list but remain in your library.',
        confirmLabel: 'Remove',
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(listsControllerProvider).batchDetach(
        widget.listId,
        _selectedIds.toList(),
      );
      if (!mounted) return;

      showLocalFeedback(
        context,
        'Removed ${_selectedIds.length} ${_selectedIds.length == 1 ? 'item' : 'items'}.',
      );
      _exitBatchMode();
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          'Could not remove items.',
          tone: LocalFeedbackTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ShelfDetailQuery(shelfId: widget.listId, sortBy: _sortBy);
    final detailAsync = ref.watch(shelfDetailProvider(query));

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxxl,
            AppSpacing.xxxl,
            AppSpacing.xxxl,
            AppSpacing.xxxl,
          ),
          child: detailAsync.when(
            loading: () => const _LoadingState(),
            error: (error, stackTrace) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load list',
              body: 'The list data could not be read right now.',
              actionLabel: 'Back to Lists',
              onActionTap: () => context.go(AppRoutes.lists),
            ),
            data: (detail) => _DetailBody(
              detail: detail,
              sortBy: _sortBy,
              batchMode: _batchMode,
              selectedIds: _selectedIds,
              onSortChanged: (value) => setState(() => _sortBy = value),
              onRename: () => _showRenameDialog(context, detail.name),
              onDelete: () => _showDeleteDialog(context, detail.name, detail.itemCount),
              onEnterBatchMode: _enterBatchMode,
              onToggleSelection: _toggleSelection,
              onReorder: _handleReorder,
            ),
          ),
        ),
        if (_batchMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xl,
            child: Center(
              child: BatchActionBar(
                selectedCount: _selectedIds.length,
                totalCount: detailAsync.valueOrNull?.items.length ?? 0,
                actionLabel: 'Remove from List',
                actionColor: AppColors.error,
                onAction: _removeFromList,
                onCancel: _exitBatchMode,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showRenameDialog(BuildContext context, String currentName) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameListDialog(initialName: currentName),
    );

    if (name == null || name.isEmpty || name == currentName) return;

    try {
      await ref.read(listsControllerProvider).renameShelf(widget.listId, name);
      if (!context.mounted) return;
      showLocalFeedback(context, 'List renamed.');
    } catch (error) {
      if (context.mounted) {
        showLocalFeedback(
          context,
          'Could not rename the list.',
          tone: LocalFeedbackTone.error,
        );
      }
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, String name, int itemCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: 'Delete "$name"?',
        body:
            'This will remove the list and all $itemCount associated item references. The media entries themselves will remain in your library.',
        confirmLabel: 'Delete',
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(listsControllerProvider).deleteShelf(widget.listId);
      if (!context.mounted) return;
      showLocalFeedback(context, 'List deleted.');
      context.go(AppRoutes.lists);
    } catch (error) {
      if (context.mounted) {
        showLocalFeedback(
          context,
          'Could not delete the list.',
          tone: LocalFeedbackTone.error,
        );
      }
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Loading list...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.sortBy,
    required this.batchMode,
    required this.selectedIds,
    required this.onSortChanged,
    required this.onRename,
    required this.onDelete,
    required this.onEnterBatchMode,
    required this.onToggleSelection,
    required this.onReorder,
  });

  final ShelfDetailViewData detail;
  final ShelfSortOption sortBy;
  final bool batchMode;
  final Set<String> selectedIds;
  final ValueChanged<ShelfSortOption> onSortChanged;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onEnterBatchMode;
  final ValueChanged<String> onToggleSelection;
  final void Function(BuildContext, List<PosterViewData>, int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailHeader(
          detail: detail,
          batchMode: batchMode,
          onRename: onRename,
          onDelete: onDelete,
          onEnterBatchMode: onEnterBatchMode,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            _SortSelector(
              value: sortBy,
              onChanged: batchMode ? null : onSortChanged,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (detail.items.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'This list is empty',
            body: 'Add titles from the library or the detail page.',
            actionLabel: 'Open Library',
            onActionTap: () => context.go(AppRoutes.library),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Items'),
              const SizedBox(height: AppSpacing.xl),
              PosterWrap(
                items: detail.items,
                variant: PosterCardVariant.libraryFooter,
                minColumns: 4,
                maxColumns: 7,
                minTileWidth: 150,
                horizontalSpacing: 24,
                verticalSpacing: 40,
                selectionMode: batchMode,
                selectedIds: selectedIds,
                onItemTap:
                    batchMode
                        ? null
                        : (value) => context.go(AppRoutes.detailFor(value.id)),
                onToggleSelection:
                    batchMode ? (item) => onToggleSelection(item.id) : null,
                showOrderControls: sortBy == ShelfSortOption.position && !batchMode,
                onReorder:
                    sortBy == ShelfSortOption.position && !batchMode
                        ? (oldIndex, newIndex) => onReorder(context, detail.items, oldIndex, newIndex)
                        : null,
              ),
            ],
          ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.detail,
    required this.batchMode,
    required this.onRename,
    required this.onDelete,
    required this.onEnterBatchMode,
  });

  final ShelfDetailViewData detail;
  final bool batchMode;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onEnterBatchMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => context.go(AppRoutes.lists),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: AppColors.onSurfaceVariant,
            tooltip: 'Back to lists',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.name,
                  style: AppTextStyles.heroTitle(theme),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${detail.itemCount} ${detail.itemCount == 1 ? 'item' : 'items'}'
                      .toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          if (!batchMode)
            PopupMenuButton<String>(
              tooltip: 'List actions',
              position: PopupMenuPosition.under,
              color: AppColors.surfaceContainerLowest,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.container),
                side: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'select',
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                      const SizedBox(width: AppSpacing.md),
                      Text('Select items', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: AppSpacing.md),
                      Text('Rename', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Delete',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'select') onEnterBatchMode();
                if (value == 'rename') onRename();
                if (value == 'delete') onDelete();
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.container),
                  border: Border.all(
                    color: AppColors.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SortSelector extends StatelessWidget {
  const _SortSelector({required this.value, required this.onChanged});

  final ShelfSortOption value;
  final ValueChanged<ShelfSortOption>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onChanged == null;

    return PopupMenuButton<ShelfSortOption>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: isDisabled ? 'Sorting disabled in batch mode' : 'Sort order',
      position: PopupMenuPosition.under,
      color: AppColors.surfaceContainerLowest,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.container),
        side: BorderSide(
          color: AppColors.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      itemBuilder: (context) {
        return ShelfSortOption.values
            .map(
              (option) => PopupMenuItem<ShelfSortOption>(
                value: option,
                child: Row(
                  children: [
                    if (option == value)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: AppSpacing.md),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(width: AppSpacing.md + 6),
                    Text(
                      option.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            option == value
                                ? AppColors.accent
                                : AppColors.onSurface,
                        fontWeight:
                            option == value ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color:
              isDisabled
                  ? AppColors.surfaceContainerLow.withValues(alpha: 0.5)
                  : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.container),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SORT:', style: theme.textTheme.labelMedium),
            const SizedBox(width: AppSpacing.sm),
            Text(
              value.label.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDisabled ? AppColors.subtleText : AppColors.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: isDisabled ? AppColors.subtleText : AppColors.subtleText,
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameListDialog extends StatefulWidget {
  const _RenameListDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameListDialog> createState() => _RenameListDialogState();
}

class _RenameListDialogState extends State<_RenameListDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      title: Text('Rename List', style: theme.textTheme.titleLarge),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'List name',
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              borderSide: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.card),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel'.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) {
              Navigator.of(context).pop(value);
            }
          },
          child: Text('Save'.toUpperCase()),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      title: Text(title, style: theme.textTheme.titleLarge),
      content: SizedBox(
        width: 360,
        child: Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel'.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel.toUpperCase()),
        ),
      ],
    );
  }
}

extension _ShelfSortOptionLabel on ShelfSortOption {
  String get label {
    switch (this) {
      case ShelfSortOption.position:
        return 'Manual order';
      case ShelfSortOption.recent:
        return 'Recently added';
      case ShelfSortOption.title:
        return 'Title';
    }
  }
}

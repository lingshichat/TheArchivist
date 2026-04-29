import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../data/lists_controller.dart';
import '../data/lists_view_data.dart';
import 'shelf_card.dart';

class ListsCenterPage extends ConsumerWidget {
  const ListsCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(shelfListCenterProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      child: dataAsync.when(
        loading: () => const _LoadingState(),
        error:
            (error, stackTrace) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load lists',
              body: 'The list data could not be read right now.',
              actionLabel: 'Retry',
              onActionTap: () => ref.invalidate(shelfListCenterProvider),
            ),
        data: (shelves) => _ListsBody(shelves: shelves),
      ),
    );
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
              'Loading lists...',
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

class _ListsBody extends StatelessWidget {
  const _ListsBody({required this.shelves});

  final List<ShelfListCardViewData> shelves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero header
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lists', style: AppTextStyles.heroTitle(theme)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Organize your media into curated collections.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showCreateDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create List'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        // Subtle separator
        Container(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${shelves.length} custom ${shelves.length == 1 ? 'list' : 'lists'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (shelves.isEmpty)
          EmptyState(
            icon: Icons.bookmark_border_outlined,
            title: 'No lists yet',
            body:
                'Create your first list to organize titles into custom collections.',
            actionLabel: 'Create List',
            onActionTap: () => _showCreateDialog(context),
          )
        else
          _ShelfGrid(shelves: shelves),
      ],
    );
  }
}

class _ShelfGrid extends ConsumerWidget {
  const _ShelfGrid({required this.shelves});

  final List<ShelfListCardViewData> shelves;

  // Aligned with PosterWrap parameters used by Library page.
  static const int _minColumns = 4;
  static const int _maxColumns = 7;
  static const double _minTileWidth = 170;
  static const double _horizontalSpacing = 28;
  static const double _verticalSpacing = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int estimatedColumns =
            ((constraints.maxWidth + _horizontalSpacing) /
                    (_minTileWidth + _horizontalSpacing))
                .floor();
        final int columns =
            estimatedColumns.clamp(_minColumns, _maxColumns);
        final double totalSpacing = (columns - 1) * _horizontalSpacing;
        final double itemWidth =
            (constraints.maxWidth - totalSpacing) / columns;

        return Wrap(
          spacing: _horizontalSpacing,
          runSpacing: _verticalSpacing,
          children:
              shelves.map((shelf) {
                return SizedBox(
                  width: itemWidth,
                  child: ShelfCard(
                    data: shelf,
                    onEdit: () => _showRenameDialog(context, ref, shelf),
                    onDelete: () => _showDeleteDialog(context, ref, shelf),
                  ),
                );
              }).toList(),
        );
      },
    );
  }
}

Future<void> _showCreateDialog(BuildContext context) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => const _CreateListDialog(),
  );

  if (name == null || name.isEmpty || !context.mounted) return;

  final container = ProviderScope.containerOf(context);
  final controller = container.read(listsControllerProvider);

  try {
    final taken = await controller.isNameTaken(name);
    if (!context.mounted) return;

    if (taken) {
      showLocalFeedback(context, 'A list with that name already exists.');
      return;
    }

    await controller.createShelf(name);
    if (!context.mounted) return;

    showLocalFeedback(context, 'List created.');
  } catch (error) {
    if (context.mounted) {
      showLocalFeedback(
        context,
        'Could not create the list.',
        tone: LocalFeedbackTone.error,
      );
    }
  }
}

Future<void> _showRenameDialog(
  BuildContext context,
  WidgetRef ref,
  ShelfListCardViewData shelf,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _RenameListDialog(initialName: shelf.name),
  );

  if (name == null || name.isEmpty || name == shelf.name) return;

  try {
    await ref.read(listsControllerProvider).renameShelf(shelf.id, name);
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

Future<void> _showDeleteDialog(
  BuildContext context,
  WidgetRef ref,
  ShelfListCardViewData shelf,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (context) => _ConfirmDialog(
          title: 'Delete "${shelf.name}"?',
          body:
              'This will remove the list and all ${shelf.itemCount} associated item references. The media entries themselves will remain in your library.',
          confirmLabel: 'Delete',
        ),
  );

  if (confirmed != true) return;

  try {
    await ref.read(listsControllerProvider).deleteShelf(shelf.id);
    if (!context.mounted) return;

    showLocalFeedback(context, 'List deleted.');
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

class _CreateListDialog extends StatefulWidget {
  const _CreateListDialog();

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final _controller = TextEditingController();

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
      title: Text('Create List', style: theme.textTheme.titleLarge),
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
          child: Text('Create'.toUpperCase()),
        ),
      ],
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
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel.toUpperCase()),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/lists_view_data.dart';

class ListPickerDialog extends ConsumerStatefulWidget {
  const ListPickerDialog({super.key, this.excludeListId});

  final String? excludeListId;

  @override
  ConsumerState<ListPickerDialog> createState() => _ListPickerDialogState();
}

class _ListPickerDialogState extends ConsumerState<ListPickerDialog> {
  final Set<String> _selectedIds = {};
  String? _newListName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataAsync = ref.watch(shelfListCenterProvider);

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      title: Text('Add to Lists', style: theme.textTheme.titleLarge),
      content: SizedBox(
        width: 400,
        height: 420,
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, stackTrace) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load lists',
                body: 'The list data could not be read right now.',
                actionLabel: 'Retry',
                onActionTap: () => ref.invalidate(shelfListCenterProvider),
              ),
          data: (shelves) {
            final available =
                shelves
                    .where((s) => s.id != widget.excludeListId)
                    .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (available.isEmpty)
                  EmptyState(
                    icon: Icons.bookmark_border_outlined,
                    title: 'No lists yet',
                    body: 'Create your first list below.',
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final shelf = available[index];
                        final isSelected = _selectedIds.contains(shelf.id);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(shelf.id);
                                } else {
                                  _selectedIds.add(shelf.id);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                                horizontal: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? AppColors.accent
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.sm,
                                      ),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? AppColors.accent
                                                : AppColors.outlineVariant,
                                        width: 2,
                                      ),
                                    ),
                                    child:
                                        isSelected
                                            ? const Icon(
                                              Icons.check_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                            : null,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shelf.name,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          '${shelf.itemCount} ${shelf.itemCount == 1 ? 'item' : 'items'}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                _NewListField(
                  onSubmitted: (name) {
                    setState(() => _newListName = name);
                  },
                ),
              ],
            );
          },
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
          onPressed:
              (_selectedIds.isNotEmpty || _newListName != null)
                  ? () => _confirm(context)
                  : null,
          child: Text('Add'.toUpperCase()),
        ),
      ],
    );
  }

  void _confirm(BuildContext context) {
    final result = ListPickerResult(
      selectedListIds: _selectedIds.toList(),
      newListName: _newListName,
    );
    Navigator.of(context).pop(result);
  }
}

class ListPickerResult {
  const ListPickerResult({
    required this.selectedListIds,
    this.newListName,
  });

  final List<String> selectedListIds;
  final String? newListName;
}

class _NewListField extends StatefulWidget {
  const _NewListField({required this.onSubmitted});

  final ValueChanged<String?> onSubmitted;

  @override
  State<_NewListField> createState() => _NewListFieldState();
}

class _NewListFieldState extends State<_NewListField> {
  final _controller = TextEditingController();
  bool _expanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_expanded) {
      return TextButton.icon(
        onPressed: () => setState(() => _expanded = true),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(
          'Create new list',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.accentStrong,
          ),
        ),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          alignment: Alignment.centerLeft,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'New list name',
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
              suffixIcon: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  setState(() => _expanded = false);
                  widget.onSubmitted(null);
                },
              ),
            ),
            onChanged: (value) => widget.onSubmitted(value.trim().isEmpty ? null : value.trim()),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/poster_wrap.dart';
import '../data/library_view_data.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  LibraryMediaType _selectedType = LibraryMediaType.movies;
  LibraryStatusFilter _selectedStatus = LibraryStatusFilter.all;
  LibrarySortOption _selectedSort = LibrarySortOption.recent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerAsync = ref.watch(libraryHeaderProvider);
    final itemsAsync = ref.watch(
      libraryItemsProvider(
        LibraryQuery(
          mediaType: _selectedType,
          statusFilter: _selectedStatus,
          sortOption: _selectedSort,
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerAsync.when(
            loading: () => const _LibraryHeaderState(
              title: 'Loading archive',
              subtitle: 'Reading your local shelves.',
            ),
            error: (error, stackTrace) => const _LibraryHeaderState(
              title: 'Archive unavailable',
              subtitle: 'The local library could not be read right now.',
            ),
            data: (header) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(header.title, style: AppTextStyles.heroTitle(theme)),
                const SizedBox(height: AppSpacing.xs),
                Text(header.subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabs = Wrap(
                  spacing: AppSpacing.xl,
                  runSpacing: AppSpacing.sm,
                  children: LibraryMediaType.values
                      .map(
                        (type) => _LibraryTab(
                          label: type.label,
                          isActive: type == _selectedType,
                          onTap: () => setState(() => _selectedType = type),
                        ),
                      )
                      .toList(),
                );

                final filters = Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _FilterPopup<LibraryStatusFilter>(
                      label: 'Status',
                      value: _selectedStatus,
                      options: LibraryStatusFilter.values,
                      itemLabel: (value) => value.label,
                      onSelected: (value) =>
                          setState(() => _selectedStatus = value),
                    ),
                    _FilterPopup<LibrarySortOption>(
                      label: 'Sort',
                      value: _selectedSort,
                      options: LibrarySortOption.values,
                      itemLabel: (value) => value.label,
                      onSelected: (value) =>
                          setState(() => _selectedSort = value),
                    ),
                  ],
                );

                if (constraints.maxWidth >= 920) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: tabs),
                      filters,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tabs,
                    const SizedBox(height: AppSpacing.lg),
                    filters,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          itemsAsync.when(
            loading: () => const _LibraryStatePanel(
              icon: Icons.hourglass_bottom_rounded,
              title: 'Loading titles',
              body: 'Preparing the current slice of your archive.',
            ),
            error: (error, stackTrace) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load the library',
              body:
                  'The selected filters could not be resolved from local data.',
              actionLabel: 'Clear Filters',
              onActionTap: () {
                setState(() {
                  _selectedStatus = LibraryStatusFilter.all;
                  _selectedSort = LibrarySortOption.recent;
                });
              },
            ),
            data: (items) {
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nothing matches this view',
                  body:
                      'Add a local entry or loosen the filters to bring titles back into view.',
                  actionLabel: '+ Add Entry',
                  onActionTap: () => context.go(AppRoutes.add),
                );
              }

              return Column(
                children: [
                  PosterWrap(
                    items: items,
                    variant: PosterCardVariant.libraryFooter,
                    minColumns: 4,
                    maxColumns: 7,
                    minTileWidth: 150,
                    horizontalSpacing: 24,
                    verticalSpacing: 40,
                    onItemTap: (value) =>
                        context.go(AppRoutes.detailFor(value.id)),
                  ),
                  const SizedBox(height: 80),
                  const Center(child: _LoadMoreButton()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LibraryHeaderState extends StatelessWidget {
  const _LibraryHeaderState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.heroTitle(theme)),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: isActive ? AppColors.accent : AppColors.subtleText,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPopup<T> extends StatelessWidget {
  const _FilterPopup({
    required this.label,
    required this.value,
    required this.options,
    required this.itemLabel,
    required this.onSelected,
  });

  final String label;
  final T value;
  final List<T> options;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onSelected,
      tooltip: '$label filter',
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
        return options
            .map(
              (option) => PopupMenuItem<T>(
                value: option,
                child: Text(
                  itemLabel(option),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: option == value
                        ? AppColors.accent
                        : AppColors.onSurface,
                    fontWeight: option == value
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
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
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.container),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${label.toUpperCase()}:', style: theme.textTheme.labelMedium),
            const SizedBox(width: AppSpacing.sm),
            Text(
              itemLabel(value).toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: AppColors.subtleText,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            'LOAD MORE ENTRIES',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.outline,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryStatePanel extends StatelessWidget {
  const _LibraryStatePanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return EmptyState(compact: true, icon: icon, title: title, body: body);
  }
}

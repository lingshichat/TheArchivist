import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/poster_view_data.dart';
import '../../../shared/widgets/poster_wrap.dart';
import '../data/library_view_data.dart';

const List<String> _statusOptions = [
  'All',
  'Wishlist',
  'In Progress',
  'Completed',
];

const List<String> _sortOptions = ['Recent', 'Title', 'Year'];

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  LibraryMediaType _selectedType = LibraryMediaType.movies;
  String _selectedStatus = _statusOptions.first;
  String _selectedSort = _sortOptions.first;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LibraryHeaderViewData header = ref.watch(libraryHeaderProvider);
    final List<PosterViewData> items = ref.watch(
      libraryItemsProvider(_selectedType),
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
          Text(header.title, style: theme.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(header.subtitle, style: theme.textTheme.bodyMedium),
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
                final Widget tabs = Wrap(
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
                final Widget filters = Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _FilterPopup(
                      label: 'Status',
                      value: _selectedStatus,
                      options: _statusOptions,
                      onSelected: (v) =>
                          setState(() => _selectedStatus = v),
                    ),
                    _FilterPopup(
                      label: 'Sort',
                      value: _selectedSort,
                      options: _sortOptions,
                      onSelected: (v) => setState(() => _selectedSort = v),
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
          if (items.isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: '这里还没有 ${_selectedType.label}',
              body: '从 Bangumi 或手动添加一条，试试看。',
              actionLabel: '+ 添加条目',
              onActionTap: () => context.go(AppRoutes.add),
            )
          else
            PosterWrap(
              items: items,
              variant: PosterCardVariant.libraryFooter,
              minColumns: 4,
              maxColumns: 7,
              minTileWidth: 150,
              horizontalSpacing: 24,
              verticalSpacing: 40,
              onItemTap: (v) => context.go(AppRoutes.detailFor(v.id)),
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 80),
            const Center(child: _LoadMoreButton()),
          ],
        ],
      ),
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
    final ThemeData theme = Theme.of(context);

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

class _FilterPopup extends StatelessWidget {
  const _FilterPopup({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return PopupMenuButton<String>(
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
              (option) => PopupMenuItem<String>(
                value: option,
                child: Text(
                  option,
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
            Text(
              '${label.toUpperCase()}:',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              value.toUpperCase(),
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
    final ThemeData theme = Theme.of(context);

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

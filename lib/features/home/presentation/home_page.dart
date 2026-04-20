import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/category_view_data.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/poster_view_data.dart';
import '../../../shared/widgets/poster_wrap.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/home_view_data.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(homeViewDataProvider);

    return dataAsync.when(
      loading: () => const _HomePageFrame(
        child: _HomeStatusState(
          title: 'Loading archive',
          body: 'Reading your local library.',
        ),
      ),
      error: (error, stackTrace) => _HomePageFrame(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load the home view',
          body: 'The local archive could not be read right now.',
          actionLabel: 'Open Library',
          onActionTap: () => context.go(AppRoutes.library),
        ),
      ),
      data: (data) => _HomePageFrame(child: _HomePageBody(data: data)),
    );
  }
}

class _HomePageFrame extends StatelessWidget {
  const _HomePageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      child: child,
    );
  }
}

class _HomePageBody extends StatelessWidget {
  const _HomePageBody({required this.data});

  final HomeViewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Continuing',
          actionLabel: 'View All',
          onActionTap: () => context.go(AppRoutes.library),
        ),
        const SizedBox(height: AppSpacing.xl),
        _HomeSection(
          items: data.continuing,
          emptyTitle: 'Nothing in progress yet',
          emptyBody: 'Move one title into In Progress and it will appear here.',
          emptyActionLabel: 'Open Library',
          onEmptyAction: () => context.go(AppRoutes.library),
          onItemTap: (value) => context.go(AppRoutes.detailFor(value.id)),
          variant: PosterCardVariant.continuing,
          minColumns: 2,
          maxColumns: 5,
          minTileWidth: 170,
          horizontalSpacing: AppSpacing.xxl,
          verticalSpacing: AppSpacing.xxl,
        ),
        const SizedBox(height: 64),
        SectionHeader(
          title: 'Recently Added',
          actionLabel: 'View All',
          onActionTap: () => context.go(AppRoutes.library),
        ),
        const SizedBox(height: AppSpacing.xl),
        _HomeSection(
          items: data.recentlyAdded,
          emptyTitle: 'No local entries yet',
          emptyBody: 'Create the first record and it will show up here.',
          emptyActionLabel: '+ Add Entry',
          onEmptyAction: () => context.go(AppRoutes.add),
          onItemTap: (value) => context.go(AppRoutes.detailFor(value.id)),
          variant: PosterCardVariant.compact,
          minColumns: 3,
          maxColumns: 8,
          minTileWidth: 112,
          horizontalSpacing: AppSpacing.xl,
          verticalSpacing: AppSpacing.xl,
        ),
        const SizedBox(height: 64),
        SectionHeader(
          title: 'Recently Finished',
          actionLabel: 'Archive',
          onActionTap: () => context.go(AppRoutes.library),
        ),
        const SizedBox(height: AppSpacing.xl),
        _HomeSection(
          items: data.recentlyFinished,
          emptyTitle: 'Nothing completed yet',
          emptyBody: 'Completed entries will gather here as the archive grows.',
          onItemTap: (value) => context.go(AppRoutes.detailFor(value.id)),
          variant: PosterCardVariant.finishedOverlay,
          minColumns: 2,
          maxColumns: 6,
          minTileWidth: 140,
          horizontalSpacing: AppSpacing.xxl,
          verticalSpacing: AppSpacing.xxl,
        ),
        const SizedBox(height: 64),
        const SectionHeader(title: 'Categories'),
        const SizedBox(height: AppSpacing.xl),
        _CategoryGrid(categories: data.categories),
      ],
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.items,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onItemTap,
    required this.variant,
    required this.minColumns,
    required this.maxColumns,
    required this.minTileWidth,
    required this.horizontalSpacing,
    required this.verticalSpacing,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final List<PosterViewData> items;
  final String emptyTitle;
  final String emptyBody;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final ValueChanged<PosterViewData> onItemTap;
  final PosterCardVariant variant;
  final int minColumns;
  final int maxColumns;
  final double minTileWidth;
  final double horizontalSpacing;
  final double verticalSpacing;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        title: emptyTitle,
        body: emptyBody,
        actionLabel: emptyActionLabel,
        onActionTap: onEmptyAction,
      );
    }

    return PosterWrap(
      items: items,
      variant: variant,
      minColumns: minColumns,
      maxColumns: maxColumns,
      minTileWidth: minTileWidth,
      horizontalSpacing: horizontalSpacing,
      verticalSpacing: verticalSpacing,
      onItemTap: onItemTap,
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<CategoryViewData> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        double cardWidth;

        if (constraints.maxWidth >= 1080) {
          cardWidth = (constraints.maxWidth - (AppSpacing.xl * 2)) / 3;
        } else if (constraints.maxWidth >= 700) {
          cardWidth = (constraints.maxWidth - AppSpacing.xl) / 2;
        } else {
          cardWidth = constraints.maxWidth;
        }

        return Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.xl,
          children: categories
              .map(
                (category) => Container(
                  width: cardWidth,
                  height: 184,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadii.container),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -12,
                        bottom: -20,
                        child: Icon(
                          category.icon,
                          size: 118,
                          color: category.accentColor.withValues(alpha: 0.12),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            category.icon,
                            color: AppColors.accent,
                            size: 28,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.label,
                                style: AppTextStyles.panelTitle(theme),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                category.description,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HomeStatusState extends StatelessWidget {
  const _HomeStatusState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: EmptyState(
          compact: true,
          icon: Icons.hourglass_bottom_rounded,
          title: title,
          body: body,
        ),
      ),
    );
  }
}

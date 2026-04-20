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
    final HomeViewData data = ref.watch(homeViewDataProvider);

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
          SectionHeader(
            title: 'Continuing',
            actionLabel: 'View All',
            onActionTap: () => context.go(AppRoutes.library),
          ),
          const SizedBox(height: AppSpacing.xl),
          _HomeSection(
            items: data.continuing,
            emptyTitle: '没有进行中的项目',
            emptyBody: '从你的档案中挑一项继续推进。',
            emptyActionLabel: '打开媒介库',
            onEmptyAction: () => context.go(AppRoutes.library),
            onItemTap: (v) => context.go(AppRoutes.detailFor(v.id)),
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
            emptyTitle: '还没有新条目',
            emptyBody: '添加新条目后会出现在这里。',
            emptyActionLabel: '+ 添加条目',
            onEmptyAction: () => context.go(AppRoutes.add),
            onItemTap: (v) => context.go(AppRoutes.detailFor(v.id)),
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
            emptyTitle: '尚无已完成条目',
            emptyBody: '把进行中的条目标记完成后，会在这里回顾。',
            onItemTap: (v) => context.go(AppRoutes.detailFor(v.id)),
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
      ),
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
    final ThemeData theme = Theme.of(context);

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
                                style: theme.textTheme.titleLarge,
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

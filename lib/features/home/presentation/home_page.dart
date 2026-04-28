import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/category_view_data.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/poster_art.dart';
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
    final heroItem = data.continuing.isNotEmpty ? data.continuing.first : null;
    final remainingContinuing =
        data.continuing.length > 1 ? data.continuing.sublist(1) : <PosterViewData>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Continuing',
          actionLabel: 'View All',
          onActionTap: () => context.go(AppRoutes.library),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (heroItem != null) ...[
          _HeroBanner(
            item: heroItem,
            onTap: () => context.go(AppRoutes.detailFor(heroItem.id)),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        if (remainingContinuing.isNotEmpty || heroItem == null)
          _HomeSection(
            items: remainingContinuing,
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
              .map((category) => _CategoryCard(category: category, width: cardWidth))
              .toList(),
        );
      },
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.category, required this.width});

  final CategoryViewData category;
  final double width;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = widget.category;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: widget.width,
        height: 184,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.surfaceContainer
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.container),
          border: Border.all(
            color: _hovered
                ? AppColors.outlineVariant.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
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
    );
  }
}

class _HeroBanner extends StatefulWidget {
  const _HeroBanner({required this.item, this.onTap});

  final PosterViewData item;
  final VoidCallback? onTap;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surfaceContainer
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.container),
            border: Border.all(
              color: _hovered
                  ? AppColors.outlineVariant.withValues(alpha: 0.3)
                  : AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.container),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 200,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      scale: _hovered ? 1.03 : 1.0,
                      child: PosterArt(item: widget.item),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.item.mediaLabel.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            height: 1.1,
                          ),
                        ),
                        if (widget.item.subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.item.subtitle!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        _HeroProgressBar(item: widget.item),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroProgressBar extends StatelessWidget {
  const _HeroProgressBar({required this.item});

  final PosterViewData item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Attempt to derive a progress ratio from subtitle text if available.
    // Expected subtitle format: 'Episode 12 / 24' or similar with two numbers.
    double? progressRatio;
    if (item.subtitle != null) {
      final numbers = RegExp(r'\d+').allMatches(item.subtitle!);
      if (numbers.length >= 2) {
        final current = int.tryParse(numbers.first.group(0)!);
        final total = int.tryParse(numbers.elementAt(1).group(0)!);
        if (current != null &&
            total != null &&
            total > 0 &&
            current <= total) {
          progressRatio = current / total;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progressRatio != null) ...[
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progressRatio,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          'Continue watching',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.subtleText,
          ),
        ),
      ],
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

import 'package:flutter/material.dart';

import '../../../shared/demo/demo_data.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/poster_art.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DemoMediaItem item = DemoData.detailItem;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxxl,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool useTwoColumns = constraints.maxWidth >= 980;

          final Widget leftColumn = _DetailSidebar(item: item);
          final Widget rightColumn = _DetailContent(item: item);

          if (!useTwoColumns) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftColumn,
                const SizedBox(height: AppSpacing.xxxl),
                rightColumn,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: leftColumn),
              const SizedBox(width: 64),
              Expanded(child: rightColumn),
            ],
          );
        },
      ),
    );
  }
}

class _DetailSidebar extends StatelessWidget {
  const _DetailSidebar({required this.item});

  final DemoMediaItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 248),
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
              child: PosterArt(item: item, muted: true),
            ),
          ),
        ),
        const SizedBox(height: 40),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 248),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STATUS', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpacing.lg),
                const _StatusStrip(),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('PROGRESS', style: theme.textTheme.labelSmall),
                    Text(
                      '124 / 150 min',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  height: 4,
                  color: AppColors.surfaceContainerHigh,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.82,
                      child: Container(color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('PERSONAL RATING', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    ...List.generate(
                      4,
                      (index) => const Padding(
                        padding: EdgeInsets.only(right: AppSpacing.sm),
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                    const Spacer(),
                    Text(
                      '8/10',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _ActionButton(
                  label: 'Resume Archiving',
                  icon: Icons.play_arrow_rounded,
                  filled: true,
                  onTap: () {},
                ),
                const SizedBox(height: AppSpacing.sm),
                _ActionButton(
                  label: 'Modify Entry',
                  icon: Icons.edit_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.item});

  final DemoMediaItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentContainer,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Text(
                item.mediaLabel.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accentStrong,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text('ID: ARC-89021', style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          item.title,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 56,
            height: 0.95,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.subtitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const _DotDivider(),
            Text(item.year, style: theme.textTheme.titleMedium),
            const _DotDivider(),
            Text('Experimental Noir', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 48),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SYNOPSIS', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.md),
              Text(
                DemoData.detailSynopsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  height: 1.7,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: DemoData.detailTags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Container(
          height: 1,
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
        const SizedBox(height: 40),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool split = constraints.maxWidth >= 760;

            final Widget notes = const _NotesWorkspace();
            final Widget history = const _HistoryWorkspace();

            if (!split) {
              return Column(
                children: [notes, const SizedBox(height: 40), history],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: notes),
                const SizedBox(width: 48),
                Expanded(child: history),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NotesWorkspace extends StatelessWidget {
  const _NotesWorkspace();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> paragraphs = DemoData.detailNotes.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ARCHIVIST NOTES', style: theme.textTheme.labelSmall),
            const Icon(
              Icons.history_edu_outlined,
              size: 16,
              color: AppColors.subtleText,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 300),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.9,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'October 14, 2024',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  paragraphs.first,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.72),
                    fontStyle: FontStyle.italic,
                    height: 1.9,
                  ),
                ),
                if (paragraphs.length > 1) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(paragraphs.sublist(1).join('\n\n')),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.xl),
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppColors.outlineVariant.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: Text(
                    '+ ADD NEW ENTRY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryWorkspace extends StatelessWidget {
  const _HistoryWorkspace();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LIFECYCLE LOG', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xl),
        const _TimelineEntry(
          title: 'STATUS UPDATED: IN PROGRESS',
          time: '14 OCT 2024 — 09:42 AM',
          active: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        const _TimelineEntry(
          title: 'ADDED TO COLLECTION',
          time: '10 OCT 2024 — 02:15 PM',
        ),
        const SizedBox(height: AppSpacing.xl),
        const _TimelineEntry(
          title: 'CATALOG ENTRY CREATED',
          time: '10 OCT 2024 — 02:10 PM',
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Row(
          children: const [
            Expanded(
              child: _StatTile(label: 'TOTAL TIME', value: '4.2h'),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatTile(label: 'REVISIONS', value: '12'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget statusCell(String label, {bool active = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: active
                ? AppColors.surfaceContainerLowest
                : Colors.transparent,
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: active ? AppColors.accent : AppColors.subtleText,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      color: AppColors.surfaceContainerHigh,
      child: Row(
        children: [
          statusCell('Wishlist'),
          const SizedBox(width: AppSpacing.xs),
          statusCell('In Progress', active: true),
          const SizedBox(width: AppSpacing.xs),
          statusCell('Completed'),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : AppColors.surfaceContainerLowest,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled
                    ? AppColors.accentForeground
                    : AppColors.onSurface,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: filled
                      ? AppColors.accentForeground
                      : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.title,
    required this.time,
    this.active = false,
  });

  final String title;
  final String time;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent
                : AppColors.outlineVariant.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: active
                      ? AppColors.onSurface
                      : AppColors.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(time, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.accentStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotDivider extends StatelessWidget {
  const _DotDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.outlineVariant.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

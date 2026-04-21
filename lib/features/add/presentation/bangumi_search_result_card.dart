import 'package:flutter/material.dart';

import '../../../features/add/data/bangumi_search_providers.dart';
import '../../../features/bangumi/data/bangumi_models.dart';
import '../../../features/bangumi/data/bangumi_type_mapper.dart';
import '../../../shared/data/local_view_adapters.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/poster_image.dart';

class BangumiSearchResultCard extends StatelessWidget {
  const BangumiSearchResultCard({
    super.key,
    required this.subject,
    required this.isBusy,
    required this.onAddTap,
    required this.onViewTap,
    this.localMatch,
  });

  final BangumiSubjectDto subject;
  final BangumiLocalMatch? localMatch;
  final bool isBusy;
  final VoidCallback onAddTap;
  final VoidCallback onViewTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTitle = _primaryTitle(subject);
    final secondaryTitle = _secondaryTitle(subject);
    final mediaLabel = _mediaLabel(subject);
    final yearLabel = _yearLabel(subject.date);
    final summary = _summaryLabel(subject.summary);
    final hasLocalMatch = localMatch != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: PosterImage(
                posterUrl: _posterUrl(subject),
                borderRadius: BorderRadius.circular(AppRadii.card),
                fallback: _BangumiPosterFallback(
                  title: primaryTitle,
                  mediaLabel: mediaLabel,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _MetaChip(label: mediaLabel),
                    if (yearLabel != null) _MetaChip(label: yearLabel),
                    if (hasLocalMatch)
                      _StatusChip(
                        label: LocalViewAdapters.statusLabel(
                          localMatch!.status,
                        ).toUpperCase(),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  primaryTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (secondaryTitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    secondaryTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _ActionArea(
            isBusy: isBusy,
            hasLocalMatch: hasLocalMatch,
            onAddTap: onAddTap,
            onViewTap: onViewTap,
          ),
        ],
      ),
    );
  }

  String _primaryTitle(BangumiSubjectDto subject) {
    final normalizedChinese = subject.nameCn?.trim();
    if (normalizedChinese != null && normalizedChinese.isNotEmpty) {
      return normalizedChinese;
    }

    final normalizedOriginal = subject.name.trim();
    if (normalizedOriginal.isNotEmpty) {
      return normalizedOriginal;
    }

    return 'Bangumi #${subject.id}';
  }

  String? _secondaryTitle(BangumiSubjectDto subject) {
    final normalizedChinese = subject.nameCn?.trim();
    final normalizedOriginal = subject.name.trim();

    if (normalizedChinese != null &&
        normalizedChinese.isNotEmpty &&
        normalizedOriginal.isNotEmpty &&
        normalizedChinese != normalizedOriginal) {
      return normalizedOriginal;
    }

    return null;
  }

  String _mediaLabel(BangumiSubjectDto subject) {
    try {
      final mediaType = BangumiTypeMapper.toMediaType(
        subject.type,
        totalEpisodes: subject.totalEpisodes,
      );
      return LocalViewAdapters.mediaTypeLabel(mediaType).toUpperCase();
    } on ArgumentError {
      return 'BANGUMI';
    }
  }

  String? _yearLabel(String? rawDate) {
    final normalizedDate = rawDate?.trim();
    if (normalizedDate == null || normalizedDate.length < 4) {
      return null;
    }
    return normalizedDate.substring(0, 4);
  }

  String _summaryLabel(String? rawSummary) {
    final normalizedSummary = rawSummary?.trim();
    if (normalizedSummary == null || normalizedSummary.isEmpty) {
      return 'Bangumi did not provide a synopsis for this title yet.';
    }
    return normalizedSummary;
  }

  String? _posterUrl(BangumiSubjectDto subject) {
    return subject.images.common?.trim().isNotEmpty == true
        ? subject.images.common
        : subject.images.large?.trim().isNotEmpty == true
        ? subject.images.large
        : subject.images.medium?.trim().isNotEmpty == true
        ? subject.images.medium
        : subject.images.grid?.trim().isNotEmpty == true
        ? subject.images.grid
        : subject.images.small?.trim().isNotEmpty == true
        ? subject.images.small
        : null;
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.isBusy,
    required this.hasLocalMatch,
    required this.onAddTap,
    required this.onViewTap,
  });

  final bool isBusy;
  final bool hasLocalMatch;
  final VoidCallback onAddTap;
  final VoidCallback onViewTap;

  @override
  Widget build(BuildContext context) {
    if (hasLocalMatch) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: isBusy ? null : onViewTap,
            child: const Text('View'),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Text(
              'ADDED',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.onSurface),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: isBusy ? null : onViewTap,
          child: const Text('View'),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: isBusy ? null : onAddTap,
          child: isBusy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentForeground,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.subtleText),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.accentStrong),
      ),
    );
  }
}

class _BangumiPosterFallback extends StatelessWidget {
  const _BangumiPosterFallback({required this.title, required this.mediaLabel});

  final String title;
  final String mediaLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.surfaceContainerHigh,
            AppColors.surfaceContainerLow,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mediaLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.subtleText),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

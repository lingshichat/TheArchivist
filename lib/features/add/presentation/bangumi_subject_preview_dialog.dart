import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/add/data/bangumi_search_providers.dart';
import '../../../features/bangumi/data/bangumi_models.dart';
import '../../../features/bangumi/data/bangumi_type_mapper.dart';
import '../../../shared/data/local_view_adapters.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/poster_image.dart';

class BangumiSubjectPreviewDialog extends ConsumerWidget {
  const BangumiSubjectPreviewDialog({
    super.key,
    required this.subjectId,
    this.localMatch,
    this.onOpenLocalTap,
  });

  final int subjectId;
  final BangumiLocalMatch? localMatch;
  final VoidCallback? onOpenLocalTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(bangumiSubjectDetailProvider(subjectId));

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920, maxHeight: 700),
        child: subjectAsync.when(
          loading: () => const _BangumiSubjectPreviewLoading(),
          error: (error, stackTrace) => _BangumiSubjectPreviewError(
            onRetry: () =>
                ref.invalidate(bangumiSubjectDetailProvider(subjectId)),
          ),
          data: (subject) => _BangumiSubjectPreviewContent(
            subject: subject,
            localMatch: localMatch,
            onOpenLocalTap: onOpenLocalTap,
          ),
        ),
      ),
    );
  }
}

class _BangumiSubjectPreviewContent extends StatelessWidget {
  const _BangumiSubjectPreviewContent({
    required this.subject,
    this.localMatch,
    this.onOpenLocalTap,
  });

  final BangumiSubjectDto subject;
  final BangumiLocalMatch? localMatch;
  final VoidCallback? onOpenLocalTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTitle = _primaryTitle(subject);
    final secondaryTitle = _secondaryTitle(subject);
    final mediaLabel = _mediaLabel(subject);
    final yearLabel = _yearLabel(subject.date);
    final releaseDate = subject.date?.trim();
    final synopsis = _summaryLabel(subject.summary);
    final totalEpisodes = subject.totalEpisodes;
    final score = subject.rating?.score;
    final rank = subject.rating?.rank;
    final ratingTotal = subject.rating?.total;
    final localStatusLabel = localMatch == null
        ? null
        : LocalViewAdapters.statusLabel(localMatch!.status).toUpperCase();

    return SizedBox(
      width: 860,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (secondaryTitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          secondaryTitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _PreviewMetaChip(label: mediaLabel),
                          _PreviewMetaChip(label: 'BGM #${subject.id}'),
                          if (yearLabel != null)
                            _PreviewMetaChip(label: yearLabel),
                          if (totalEpisodes != null && totalEpisodes > 0)
                            _PreviewMetaChip(label: '$totalEpisodes EPS'),
                          if (score != null)
                            _PreviewMetaChip(
                              label: '★ ${score.toStringAsFixed(1)}',
                            ),
                          if (rank != null) _PreviewMetaChip(label: '#$rank'),
                          if (localStatusLabel != null)
                            _PreviewStatusChip(label: localStatusLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final poster = SizedBox(
                    width: 220,
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
                  );

                  final detailContent = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Synopsis', style: AppTextStyles.panelTitle(theme)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        synopsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text('Details', style: AppTextStyles.panelTitle(theme)),
                      const SizedBox(height: AppSpacing.md),
                      _BangumiDetailRow(
                        label: 'Release date',
                        value: releaseDate ?? 'Unknown',
                      ),
                      _BangumiDetailRow(label: 'Type', value: mediaLabel),
                      _BangumiDetailRow(
                        label: 'Episodes',
                        value: totalEpisodes?.toString() ?? 'Unknown',
                      ),
                      _BangumiDetailRow(
                        label: 'Score',
                        value: score?.toStringAsFixed(1) ?? 'Unknown',
                      ),
                      _BangumiDetailRow(
                        label: 'Rank',
                        value: rank?.toString() ?? 'Unknown',
                      ),
                      _BangumiDetailRow(
                        label: 'Ratings',
                        value: ratingTotal?.toString() ?? 'Unknown',
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 720) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(alignment: Alignment.centerLeft, child: poster),
                          const SizedBox(height: AppSpacing.xxl),
                          detailContent,
                        ],
                      ),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      poster,
                      const SizedBox(width: AppSpacing.xxxl),
                      Expanded(
                        child: SingleChildScrollView(child: detailContent),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (localMatch != null && onOpenLocalTap != null)
                  OutlinedButton.icon(
                    onPressed: onOpenLocalTap,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open Local'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
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

class _BangumiSubjectPreviewLoading extends StatelessWidget {
  const _BangumiSubjectPreviewLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 760,
      height: 420,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Loading Bangumi details...',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BangumiSubjectPreviewError extends StatelessWidget {
  const _BangumiSubjectPreviewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 760,
      height: 420,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Could not load Bangumi details',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try again in a moment.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMetaChip extends StatelessWidget {
  const _PreviewMetaChip({required this.label});

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

class _PreviewStatusChip extends StatelessWidget {
  const _PreviewStatusChip({required this.label});

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

class _BangumiDetailRow extends StatelessWidget {
  const _BangumiDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.subtleText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
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

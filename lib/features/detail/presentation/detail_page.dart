import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/data/app_database.dart';
import '../../../shared/data/local_view_adapters.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../../../shared/widgets/poster_art.dart';
import '../data/detail_actions_controller.dart';
import '../data/detail_view_data.dart';

class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({super.key, required this.mediaId});

  final String mediaId;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final viewAsync = ref.watch(detailViewDataProvider(widget.mediaId));

    return viewAsync.when(
      loading: () => const _DetailPageFrame(
        child: _DetailStatusPanel(
          icon: Icons.hourglass_bottom_rounded,
          title: 'Loading entry',
          body: 'Reading the local record.',
        ),
      ),
      error: (error, stackTrace) => const _DetailPageFrame(
        child: _DetailStatusPanel(
          icon: Icons.error_outline_rounded,
          title: 'Could not load the entry',
          body: 'The local record could not be read right now.',
        ),
      ),
      data: (view) {
        if (view == null) {
          return _DetailPageFrame(
            child: EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Entry not found',
              body:
                  'The record may have been deleted or never existed locally.',
              actionLabel: 'Open Library',
              onActionTap: () => context.go(AppRoutes.library),
            ),
          );
        }

        return _DetailPageFrame(
          child: _DetailBody(
            view: view,
            isSaving: _isSaving,
            onPrimaryTap: () => _handleQuickAction(view),
            onEditTap: () => _handleEdit(view),
            onDeleteTap: _handleDelete,
          ),
        );
      },
    );
  }

  Future<void> _handleQuickAction(DetailViewData view) async {
    setState(() => _isSaving = true);

    try {
      await ref
          .read(detailActionsControllerProvider)
          .applyQuickStatus(widget.mediaId, view.primaryActionStatus);

      if (!mounted) {
        return;
      }

      showLocalFeedback(context, 'Saved locally.');
    } catch (error) {
      if (mounted) {
        showLocalFeedback(context, 'Could not update the entry.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleEdit(DetailViewData view) async {
    final result = await showDialog<DetailEntryUpdateInput>(
      context: context,
      builder: (context) => _EditEntryDialog(view: view),
    );

    if (result == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(detailActionsControllerProvider)
          .saveChanges(widget.mediaId, result);

      if (!mounted) {
        return;
      }

      showLocalFeedback(context, 'Saved locally.');
    } catch (error) {
      if (mounted) {
        showLocalFeedback(context, 'Could not save changes.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: const Text('Delete this entry?'),
        content: const Text(
          'The record will be hidden from Home, Library, and Detail views.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(detailActionsControllerProvider).delete(widget.mediaId);

      if (!mounted) {
        return;
      }

      showLocalFeedback(context, 'Deleted locally.');
      context.go(AppRoutes.library);
    } catch (error) {
      if (mounted) {
        showLocalFeedback(context, 'Could not delete the entry.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _DetailPageFrame extends StatelessWidget {
  const _DetailPageFrame({required this.child});

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

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.view,
    required this.isSaving,
    required this.onPrimaryTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final DetailViewData view;
  final bool isSaving;
  final VoidCallback onPrimaryTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageWidth = constraints.maxWidth;
        final useTwoColumns = pageWidth >= 820;
        final sidebarWidth = (pageWidth * 0.26).clamp(216.0, 280.0).toDouble();
        final columnGap = (pageWidth * 0.045).clamp(32.0, 64.0).toDouble();

        final leftColumn = _DetailSidebar(
          view: view,
          isSaving: isSaving,
          onPrimaryTap: onPrimaryTap,
          onEditTap: onEditTap,
          onDeleteTap: onDeleteTap,
        );
        final rightColumn = _DetailContent(view: view);

        if (!useTwoColumns) {
          return SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: sidebarWidth, child: leftColumn),
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(width: double.infinity, child: rightColumn),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: sidebarWidth, child: leftColumn),
            SizedBox(width: columnGap),
            Expanded(child: rightColumn),
          ],
        );
      },
    );
  }
}

class _DetailSidebar extends StatelessWidget {
  const _DetailSidebar({
    required this.view,
    required this.isSaving,
    required this.onPrimaryTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final DetailViewData view;
  final bool isSaving;
  final VoidCallback onPrimaryTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = view.poster;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.15),
              ),
            ),
            child: PosterArt(item: poster),
          ),
        ),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(color: AppColors.surfaceContainerLow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STATUS', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.lg),
              _StatusStrip(status: view.status),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(view.progressLabel, style: theme.textTheme.labelSmall),
                  Flexible(
                    child: Text(
                      view.progressSummary,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
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
                    widthFactor: view.progressRatio.clamp(0, 1),
                    child: Container(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('PERSONAL RATING', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.md),
              _RatingRow(score: view.score),
              const SizedBox(height: AppSpacing.xl),
              _ActionButton(
                label: view.primaryActionLabel,
                icon: Icons.play_arrow_rounded,
                filled: true,
                onTap: isSaving ? null : onPrimaryTap,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ActionButton(
                label: 'Modify Entry',
                icon: Icons.edit_outlined,
                onTap: isSaving ? null : onEditTap,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: isSaving ? null : onDeleteTap,
                  child: Text(
                    'DELETE ENTRY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.view});

  final DetailViewData view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = view.poster;
    final subtitle = poster.subtitle;
    final year = poster.year;
    final synopsis = view.synopsis;

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleFontSize = (constraints.maxWidth * 0.078)
            .clamp(40.0, 56.0)
            .toDouble();

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
                    poster.mediaLabel.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.accentStrong,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(view.archiveId, style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              poster.title,
              style: AppTextStyles.heroTitle(theme).copyWith(
                fontSize: titleFontSize,
                letterSpacing: -1.1,
                height: 0.95,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                if (subtitle != null && year != null) const _DotDivider(),
                if (year != null)
                  Text(year, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 48),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SYNOPSIS', style: theme.textTheme.labelSmall),
                  const SizedBox(height: AppSpacing.md),
                  if (synopsis != null && synopsis.isNotEmpty)
                    Text(
                      synopsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        height: 1.7,
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  else
                    const EmptyState(
                      compact: true,
                      icon: Icons.article_outlined,
                      title: 'No synopsis',
                      body:
                          'Add a summary from the edit dialog when you are ready.',
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  _ChipSection(
                    title: 'TAGS',
                    values: view.tags,
                    emptyTitle: 'No tags yet',
                    emptyBody: 'Tag the entry to make filtering easier later.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _ChipSection(
                    title: 'LISTS',
                    values: view.shelves,
                    emptyTitle: 'No lists yet',
                    emptyBody: 'Attach this entry to one or more local lists.',
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
                final split = constraints.maxWidth >= 760;
                final notes = _NotesWorkspace(notes: view.notes);
                final history = _HistoryWorkspace(
                  entries: view.lifecycle,
                  progressSummary: view.progressSummary,
                  updateCount: view.updateCount,
                );

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
      },
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.values,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final String title;
  final List<String> values;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.md),
        if (values.isEmpty)
          EmptyState(
            compact: true,
            icon: Icons.label_outline_rounded,
            title: emptyTitle,
            body: emptyBody,
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: values
                .map(
                  (value) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixedDim,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      value.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _NotesWorkspace extends StatelessWidget {
  const _NotesWorkspace({required this.notes});

  final DetailNotesEntry? notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        if (notes == null)
          const EmptyState(
            compact: true,
            icon: Icons.note_add_outlined,
            title: 'No notes yet',
            body: 'Open Modify Entry to store private notes for this record.',
          )
        else
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
              style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.9,
                  ) ??
                  const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.9,
                    color: AppColors.onSurfaceVariant,
                  ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notes!.date,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(notes!.body),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryWorkspace extends StatelessWidget {
  const _HistoryWorkspace({
    required this.entries,
    required this.progressSummary,
    required this.updateCount,
  });

  final List<DetailLifecycleEntry> entries;
  final String progressSummary;
  final int updateCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LIFECYCLE LOG', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xl),
        if (entries.isEmpty)
          const EmptyState(
            compact: true,
            icon: Icons.history_outlined,
            title: 'No activity yet',
            body:
                'Local changes to status, rating, progress, and notes will appear here.',
          )
        else
          ...List.generate(entries.length, (index) {
            final entry = entries[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == entries.length - 1 ? 0 : AppSpacing.xl,
              ),
              child: _TimelineEntry(
                title: entry.title,
                time: entry.time,
                active: entry.current,
              ),
            );
          }),
        const SizedBox(height: AppSpacing.xxxl),
        Row(
          children: [
            Expanded(
              child: _StatTile(label: 'PROGRESS', value: progressSummary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatTile(label: 'UPDATES', value: '$updateCount'),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.status});

  final UnifiedStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: UnifiedStatus.values.map((value) {
        final active = value == status;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.surfaceContainerLowest
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Text(
            LocalViewAdapters.statusLabel(value).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: active ? AppColors.accent : AppColors.subtleText,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filledStars = score == null ? 0 : (score! / 2).round().clamp(0, 5);

    return Row(
      children: [
        ...List.generate(5, (index) {
          final filled = index < filledStars;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(
              Icons.star_rounded,
              size: 18,
              color: filled
                  ? AppColors.accent
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
          );
        }),
        const Spacer(),
        Text(
          score == null ? 'Not rated' : '$score/10',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ],
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
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Material(
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
              color: filled
                  ? AppColors.accent
                  : AppColors.surfaceContainerLowest,
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
    final theme = Theme.of(context);

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
    final theme = Theme.of(context);

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

class _DetailStatusPanel extends StatelessWidget {
  const _DetailStatusPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: EmptyState(compact: true, icon: icon, title: title, body: body),
      ),
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  const _EditEntryDialog({required this.view});

  final DetailViewData view;

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _scoreController;
  late final TextEditingController _progressController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagsController;
  late final TextEditingController _shelvesController;

  late UnifiedStatus _status;

  @override
  void initState() {
    super.initState();
    final view = widget.view;

    _status = view.status;
    _scoreController = TextEditingController(
      text: view.score?.toString() ?? '',
    );
    _progressController = TextEditingController(
      text: view.progressValue == null
          ? ''
          : _formatProgressValue(view.mediaType, view.progressValue!),
    );
    _notesController = TextEditingController(text: view.notes?.body ?? '');
    _tagsController = TextEditingController(text: view.tags.join(', '));
    _shelvesController = TextEditingController(text: view.shelves.join(', '));
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _progressController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    _shelvesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldTextStyle = AppFormStyles.fieldText(theme);
    const surface = AppFormSurface.lowest;

    InputDecoration decoration(String label, {String? hintText}) {
      return AppFormStyles.fieldDecoration(
        theme,
        label: label,
        hintText: hintText,
        surface: surface,
      );
    }

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.all(AppSpacing.xxl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modify Entry', style: AppTextStyles.heroTitle(theme)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Save changes directly into the local archive.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  DropdownButtonFormField<UnifiedStatus>(
                    initialValue: _status,
                    style: fieldTextStyle,
                    iconEnabledColor: AppFormStyles.fieldIconColor,
                    dropdownColor: AppFormStyles.dropdownColor(surface),
                    decoration: decoration('Status'),
                    items: UnifiedStatus.values
                        .map(
                          (value) => DropdownMenuItem<UnifiedStatus>(
                            value: value,
                            child: Text(LocalViewAdapters.statusLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _status = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _scoreController,
                    style: fieldTextStyle,
                    keyboardType: TextInputType.number,
                    decoration: decoration('Score', hintText: '0-10'),
                    validator: (value) {
                      final trimmed = value?.trim();
                      if (trimmed == null || trimmed.isEmpty) {
                        return null;
                      }
                      final score = int.tryParse(trimmed);
                      if (score == null || score < 0 || score > 10) {
                        return 'Use a score from 0 to 10.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _progressController,
                    style: fieldTextStyle,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: decoration(
                      _progressFieldLabel(widget.view.mediaType),
                    ),
                    validator: (value) =>
                        _validateProgress(value, widget.view.mediaType),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _notesController,
                    style: fieldTextStyle,
                    decoration: decoration('Notes'),
                    maxLines: 6,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _tagsController,
                    style: fieldTextStyle,
                    decoration: decoration(
                      'Tags',
                      hintText: 'Keywords, comma separated',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _shelvesController,
                    style: fieldTextStyle,
                    decoration: decoration(
                      'Shelves',
                      hintText: 'Custom collections, comma separated',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Row(
                    children: [
                      OutlinedButton(
                        style: AppFormStyles.secondaryButton(
                          theme,
                          surface: surface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Save locally'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      DetailEntryUpdateInput(
        mediaType: widget.view.mediaType,
        status: _status,
        score: _parseScore(_scoreController.text),
        progressValue: _parseProgress(_progressController.text),
        notes: _notesController.text,
        tags: _splitComma(_tagsController.text),
        shelves: _splitComma(_shelvesController.text),
      ),
    );
  }

  String? _validateProgress(String? value, MediaType mediaType) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final parsed = num.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      return 'Use a valid number.';
    }

    if ((mediaType == MediaType.tv || mediaType == MediaType.book) &&
        parsed.toInt() != parsed) {
      return 'Use a whole number.';
    }

    return null;
  }

  int? _parseScore(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  double? _parseProgress(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  List<String> _splitComma(String rawValue) {
    return rawValue
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }
}

String _progressFieldLabel(MediaType mediaType) {
  switch (mediaType) {
    case MediaType.tv:
      return 'Current episode';
    case MediaType.book:
      return 'Current page';
    case MediaType.movie:
      return 'Current minute';
    case MediaType.game:
      return 'Played hours';
  }
}

String _formatProgressValue(MediaType mediaType, double value) {
  switch (mediaType) {
    case MediaType.tv:
    case MediaType.book:
    case MediaType.movie:
      return value.round().toString();
    case MediaType.game:
      return value.toStringAsFixed(1);
  }
}

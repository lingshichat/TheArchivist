import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/data/providers.dart';
import '../../../shared/theme/app_theme.dart';
import 'bangumi_connection_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxxl,
            AppSpacing.xxxl,
            AppSpacing.xxxl,
            96,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _SettingsContent(maxWidth: constraints.maxWidth),
          ),
        );
      },
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bool useSplitLayout = maxWidth >= 1100;

    final Widget primaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _AppearanceSection(),
        SizedBox(height: 64),
        _PreferencesSection(),
      ],
    );

    final Widget secondaryColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _LocalDataSection(),
        SizedBox(height: 48),
        BangumiConnectionSection(),
        SizedBox(height: 32),
        _SyncSection(),
        SizedBox(height: 32),
        _AboutSection(),
      ],
    );

    if (!useSplitLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [primaryColumn, const SizedBox(height: 48), secondaryColumn],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: primaryColumn),
        const SizedBox(width: 48),
        Expanded(flex: 5, child: secondaryColumn),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: AppTextStyles.heroTitle(theme)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Configure the visual footprint of the archive gallery.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _InlineSettingRow(
          title: 'Theme mode',
          subtitle: 'Select your preferred lighting environment.',
          trailing: const _ModeSwitcher(),
        ),
        const SizedBox(height: AppSpacing.xl),
        _InlineSettingRow(
          title: 'Interface density',
          subtitle: 'Control the vertical spacing of library lists.',
          trailing: const _SelectPill(value: 'Comfortable', width: 140),
        ),
        const SizedBox(height: 28),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Poster wall scale',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Adjust the size of media covers in grid view.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  '120%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceContainerHigh,
                thumbColor: AppColors.accent,
                overlayColor: Colors.transparent,
                trackHeight: 4,
              ),
              child: Slider(
                value: 120.0,
                min: 50.0,
                max: 200.0,
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Logging Preferences', style: AppTextStyles.heroTitle(theme)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Define how metadata and curation tools behave.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.container),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool split = constraints.maxWidth >= 420;

                  final Widget left = const _LabeledSelect(
                    label: 'DEFAULT SORT',
                    value: 'Recently Added',
                  );
                  final Widget right = const _LabeledSelect(
                    label: 'START PAGE',
                    value: 'Recent Activity',
                  );

                  if (!split) {
                    return Column(
                      children: [
                        left,
                        SizedBox(height: AppSpacing.lg),
                        right,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: left),
                      SizedBox(width: AppSpacing.lg),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                height: 1,
                color: AppColors.outlineVariant.withValues(alpha: 0.06),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Star rating style',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Choose between 5-star or 10-point scales.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  const Row(
                    children: [
                      _RatingStyleButton(
                        selected: true,
                        child: Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: AppColors.accent,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      _RatingStyleButton(child: Text('10')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocalDataSection extends StatelessWidget {
  const _LocalDataSection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storage_rounded,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Local Data', style: AppTextStyles.panelTitle(theme)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Text(
              'CURRENT: LOCAL MODE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.accentForeground,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('STORAGE DIRECTORY', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadii.container),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    r'C:\Users\Archivist\AppData\Local\MediaDB',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.content_copy_outlined,
                  size: 14,
                  color: AppColors.subtleText,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool split = constraints.maxWidth >= 320;

              final Widget export = _DataButton(
                label: 'Export Backup',
                icon: Icons.file_upload_outlined,
                filled: true,
                onTap: () {},
              );
              final Widget import = _DataButton(
                label: 'Import Archive',
                icon: Icons.file_download_outlined,
                onTap: () {},
              );

              if (!split) {
                return Column(
                  children: [
                    export,
                    const SizedBox(height: AppSpacing.sm),
                    import,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: export),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: import),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);
    final statusColor = _statusColor(syncStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined, size: 18, color: statusColor),
              const SizedBox(width: AppSpacing.sm),
              Text('Cloud Sync', style: AppTextStyles.panelTitle(theme)),
              const Spacer(),
              _SyncBadge(label: _statusLabel(syncStatus), color: statusColor),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Local-first device sync stores only a minimal health snapshot in this phase.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SyncFactRow(
            label: 'CURRENT STATE',
            value: _statusDescription(syncStatus),
          ),
          const SizedBox(height: AppSpacing.md),
          _SyncFactRow(
            label: 'LAST SYNC',
            value: _formatTimestamp(syncStatus.lastCompletedAt),
          ),
          const SizedBox(height: AppSpacing.md),
          _SyncFactRow(
            label: 'LAST FAILURE',
            value: syncStatus.lastErrorSummary ?? 'None recorded',
            isWarning: syncStatus.lastErrorSummary != null,
          ),
          const SizedBox(height: AppSpacing.md),
          _SyncFactRow(
            label: 'CONFLICTS',
            value: syncStatus.hasConflicts
                ? 'Pending text conflict copies'
                : 'No pending conflicts',
            isWarning: syncStatus.hasConflicts,
          ),
        ],
      ),
    );
  }

  String _statusLabel(SyncStatusState state) {
    if (state.isRunning) {
      return 'Syncing';
    }
    if (state.hasConflicts) {
      return 'Conflict';
    }
    if (state.lastErrorSummary != null) {
      return 'Failed';
    }
    if (state.lastCompletedAt != null) {
      return 'Synced';
    }
    return 'Ready';
  }

  Color _statusColor(SyncStatusState state) {
    if (state.hasConflicts || state.lastErrorSummary != null) {
      return AppColors.error;
    }
    if (state.isRunning) {
      return AppColors.accent;
    }
    return AppColors.subtleText;
  }

  String _statusDescription(SyncStatusState state) {
    if (state.isRunning) {
      return 'Sync is running with ${state.pendingCount} pending item(s).';
    }
    if (state.hasConflicts) {
      return 'Sync is paused for user review of text conflicts.';
    }
    if (state.lastErrorSummary != null) {
      return 'Last sync finished with an error.';
    }
    if (state.pendingCount > 0) {
      return '${state.pendingCount} pending item(s) waiting for sync.';
    }
    return 'Ready for the next sync run.';
  }

  String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'Never synced';
    }

    String twoDigits(int input) => input.toString().padLeft(2, '0');
    final local = value.toLocal();
    final date =
        '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
    final time = '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    return '$date $time';
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _SyncFactRow extends StatelessWidget {
  const _SyncFactRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = isWarning ? AppColors.error : AppColors.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadii.container),
            ),
            child: const Icon(
              Icons.token_outlined,
              size: 18,
              color: AppColors.subtleText,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Archivist Desktop',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Version 1.0.4-WP1', style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'A personal project dedicated to the preservation and curation of digital media. Built for the quiet explorer.\n© 2024 Curation Labs.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineSettingRow extends StatelessWidget {
  const _InlineSettingRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final Widget description = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        );

        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              description,
              const SizedBox(height: AppSpacing.lg),
              trailing,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: description),
            const SizedBox(width: AppSpacing.xl),
            Flexible(child: trailing),
          ],
        );
      },
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget mode(String label, {bool active = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.container),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: active ? AppColors.accent : AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [mode('Light', active: true), mode('Dark'), mode('System')],
      ),
    );
  }
}

class _SelectPill extends StatelessWidget {
  const _SelectPill({required this.value, this.width});

  final String value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: AppColors.subtleText,
          ),
        ],
      ),
    );
  }
}

class _LabeledSelect extends StatelessWidget {
  const _LabeledSelect({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        _SelectPill(value: value),
      ],
    );
  }
}

class _RatingStyleButton extends StatelessWidget {
  const _RatingStyleButton({required this.child, this.selected = false});

  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.1)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style:
            Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ) ??
            const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
        child: child,
      ),
    );
  }
}

class _DataButton extends StatelessWidget {
  const _DataButton({
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
        borderRadius: BorderRadius.circular(AppRadii.container),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.container),
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: filled
                        ? AppColors.accentForeground
                        : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

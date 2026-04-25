import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/data/providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/local_feedback.dart';
import 'bangumi_connection_section.dart';
import 'sync_target_section.dart';

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
        SyncTargetSection(),
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

class _LocalDataSection extends ConsumerStatefulWidget {
  const _LocalDataSection();

  @override
  ConsumerState<_LocalDataSection> createState() => _LocalDataSectionState();
}

class _LocalDataSectionState extends ConsumerState<_LocalDataSection> {
  bool _isExporting = false;
  bool _isImporting = false;

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
                label: _isExporting ? 'Exporting...' : 'Export Backup',
                icon: Icons.file_upload_outlined,
                filled: true,
                onTap: _isExporting || _isImporting ? null : _handleExport,
              );
              final Widget import = _DataButton(
                label: _isImporting ? 'Importing...' : 'Import Archive',
                icon: Icons.file_download_outlined,
                onTap: _isExporting || _isImporting ? null : _handleImport,
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

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final snapshotService = ref.read(snapshotServiceProvider);
      final jsonContent = await snapshotService.exportSnapshot();

      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Snapshot',
        fileName: 'record-anywhere-backup-${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-').substring(0, 19)}.snapshot.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: utf8.encode(jsonContent),
      );

      if (outputPath != null && mounted) {
        showLocalFeedback(context, 'Snapshot exported successfully.');
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          'Export failed: $error',
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleImport() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Snapshot',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    setState(() => _isImporting = true);
    try {
      final file = File(filePath);
      final jsonContent = await file.readAsString();

      final snapshotService = ref.read(snapshotServiceProvider);
      final importResult = await snapshotService.importSnapshot(jsonContent);

      if (mounted) {
        final applied = importResult.appliedCount;
        final skipped = importResult.skippedCount;
        final conflicts = importResult.conflictCount;
        final failed = importResult.failedCount;

        final segments = <String>[
          'Applied $applied',
          'Skipped $skipped',
        ];
        if (conflicts > 0) segments.add('Conflicts $conflicts');
        if (failed > 0) segments.add('Failed $failed');

        showLocalFeedback(
          context,
          'Import complete. ${segments.join(' · ')}',
          tone: importResult.hasFailures
              ? LocalFeedbackTone.error
              : LocalFeedbackTone.success,
        );
      }
    } catch (error) {
      if (mounted) {
        showLocalFeedback(
          context,
          'Import failed: $error',
          tone: LocalFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
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
  final VoidCallback? onTap;
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

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
            child: const _SettingsContent(),
          ),
        );
      },
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocalDataSection(),
        SizedBox(height: 48),
        BangumiConnectionSection(),
        SizedBox(height: 32),
        SyncTargetSection(),
        SizedBox(height: 32),
        _AboutSection(),
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
              color: AppColors.surfaceContainerHigh,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.container),
            child: Image.asset(
              'assets/icon.png',
              width: 48,
              height: 48,
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
                Text('Version 0.1.0', style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'A personal project dedicated to the preservation and curation of digital media. Built for the quiet explorer.\n© 2026 AnyRecord Team.',
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

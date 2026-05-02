import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../update/data/providers.dart';
import '../../update/data/update_models.dart';
import '../../sync/data/providers.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/local_feedback.dart';
import '../../../shared/widgets/section_card.dart';
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
        SizedBox(height: 32),
        _UpdateSection(),
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
        fileName:
            'record-anywhere-backup-${DateTime.now().toLocal().toIso8601String().replaceAll(':', '-').substring(0, 19)}.snapshot.json',
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

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final version = ref.watch(currentAppVersionProvider);

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
                Text(
                  version.when(
                    data: (value) => 'Version $value',
                    loading: () => 'Version loading…',
                    error: (error, stackTrace) => 'Version unavailable',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
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

class _UpdateSection extends ConsumerWidget {
  const _UpdateSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(updateControllerProvider);
    final isChecking = state.status == UpdateStatus.checking;
    final isDownloading = state.status == UpdateStatus.downloading;
    final isDownloaded = state.status == UpdateStatus.downloaded;
    final canInstall = state.downloadedFilePath != null &&
        state.downloadedFilePath!.isNotEmpty;
    final isInstalling = state.status == UpdateStatus.installing;
    final isBusy = isChecking || isDownloading || isInstalling;

    return SectionCard(
      title: 'Updates',
      leading: _AnimatedUpdateIcon(isChecking: isChecking),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _UpdateStatusBadge(status: state.status),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () async {
                        await ref
                            .read(updateControllerProvider.notifier)
                            .checkForUpdate(UpdateCheckTrigger.manual);
                      },
                icon: isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(isChecking ? 'Checking...' : 'Check Updates'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _statusText(state),
              key: ValueKey(state.status),
              style: theme.textTheme.bodySmall?.copyWith(
                color: state.status == UpdateStatus.error
                    ? AppColors.error
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: state.updateInfo != null
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: _UpdateInfoPanel(updateInfo: state.updateInfo!),
                  )
                : const SizedBox.shrink(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: isDownloading ||
                    isDownloaded ||
                    isInstalling ||
                    canInstall ||
                    state.status == UpdateStatus.cancelled
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: _UpdateDownloadProgress(state: state),
                  )
                : const SizedBox.shrink(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: state.updateInfo != null
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: isDownloading
                                  ? OutlinedButton.icon(
                                      onPressed: () => ref
                                          .read(
                                              updateControllerProvider.notifier)
                                          .cancelDownload(),
                                      icon: const Icon(
                                          Icons.close_rounded,
                                          size: 16),
                                      label: const Text('Cancel Download'),
                                    )
                                  : FilledButton.icon(
                                      onPressed: canInstall ||
                                              isChecking ||
                                              isInstalling
                                          ? null
                                          : () async {
                                              await ref
                                                  .read(
                                                      updateControllerProvider
                                                          .notifier)
                                                  .downloadUpdate();
                                            },
                                      icon: const Icon(
                                          Icons.download_rounded,
                                          size: 16),
                                      label: const Text('Download Update'),
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: !canInstall || isInstalling
                                    ? null
                                    : () async {
                                        await ref
                                            .read(
                                                updateControllerProvider
                                                    .notifier)
                                            .installDownloadedUpdate();
                                      },
                                icon: isInstalling
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accentForeground,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.install_desktop_rounded,
                                        size: 16),
                                label: Text(
                                    isInstalling ? 'Opening...' : 'Install Now'),
                              ),
                            ),
                          ],
                        ),
                        if (canInstall &&
                            state.updateInfo!.platform ==
                                UpdatePlatform.windows) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'The installer may ask you to close The Archivist before continuing.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: AppSpacing.lg),
            _MockUpdateToggle(),
          ],
        ],
      ),
    );
  }

  String _statusText(UpdateState state) {
    if (state.message != null && state.message!.trim().isNotEmpty) {
      return state.message!;
    }

    switch (state.status) {
      case UpdateStatus.idle:
        return 'Check GitHub Releases for Windows and Android update packages.';
      case UpdateStatus.checking:
        return 'Checking GitHub Releases…';
      case UpdateStatus.upToDate:
        return 'You are running the latest version.';
      case UpdateStatus.updateAvailable:
        return 'A new version is ready to download.';
      case UpdateStatus.downloading:
        return 'Downloading the update package…';
      case UpdateStatus.cancelled:
        return 'Download cancelled.';
      case UpdateStatus.downloaded:
        return 'Update package downloaded. Confirm when you are ready to install.';
      case UpdateStatus.installing:
        return 'Opening the platform installer…';
      case UpdateStatus.error:
        return 'Update check failed. Try again later.';
    }
  }
}

class _AnimatedUpdateIcon extends StatefulWidget {
  const _AnimatedUpdateIcon({required this.isChecking});

  final bool isChecking;

  @override
  State<_AnimatedUpdateIcon> createState() => _AnimatedUpdateIconState();
}

class _AnimatedUpdateIconState extends State<_AnimatedUpdateIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _updatePulse();
  }

  @override
  void didUpdateWidget(_AnimatedUpdateIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePulse();
  }

  void _updatePulse() {
    if (widget.isChecking) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: Icon(
        Icons.system_update_alt_rounded,
        size: 18,
        color: widget.isChecking ? AppColors.accent : AppColors.subtleText,
      ),
    );
  }
}

class _UpdateStatusBadge extends StatelessWidget {
  const _UpdateStatusBadge({required this.status});

  final UpdateStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _label;
    final color = _color;

    if (label == null) return const SizedBox.shrink();

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
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String? get _label {
    switch (status) {
      case UpdateStatus.checking:
        return 'CHECKING';
      case UpdateStatus.upToDate:
        return 'UP TO DATE';
      case UpdateStatus.updateAvailable:
        return 'UPDATE AVAILABLE';
      case UpdateStatus.downloading:
        return 'DOWNLOADING';
      case UpdateStatus.downloaded:
        return 'DOWNLOADED';
      case UpdateStatus.installing:
        return 'INSTALLING';
      case UpdateStatus.error:
        return 'ERROR';
      case UpdateStatus.cancelled:
        return 'CANCELLED';
      case UpdateStatus.idle:
        return null;
    }
  }

  Color get _color {
    switch (status) {
      case UpdateStatus.error:
      case UpdateStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.accent;
    }
  }
}

class _MockUpdateToggle extends ConsumerWidget {
  const _MockUpdateToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMock = ref.watch(mockModeProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.container),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bug_report_outlined,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Preview mock data',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Switch(
            value: isMock,
            onChanged: (value) {
              ref.read(mockModeProvider.notifier).state = value;
              if (!value) {
                ref.read(updateControllerProvider.notifier).reset();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _UpdateInfoPanel extends StatelessWidget {
  const _UpdateInfoPanel({required this.updateInfo});

  final AppUpdateInfo updateInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = updateInfo.release.body.trim().isEmpty
        ? 'No release notes were provided.'
        : updateInfo.release.body.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                updateInfo.currentVersion,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                updateInfo.latestVersion,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            updateInfo.asset.name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            notes,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _UpdateDownloadProgress extends StatelessWidget {
  const _UpdateDownloadProgress({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = state.progress?.fraction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: AppColors.surfaceContainerHighest,
                color: AppColors.accent,
              ),
            ),
            if (fraction != null) ...[
              const SizedBox(width: AppSpacing.md),
              Text(
                '${(fraction * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(_progressText(state), style: theme.textTheme.bodySmall),
      ],
    );
  }

  String _progressText(UpdateState state) {
    final progress = state.progress;
    if (state.status == UpdateStatus.installing) {
      return 'Opening installer…';
    }
    if (state.status == UpdateStatus.downloaded) {
      return 'Download complete.';
    }
    if (state.status == UpdateStatus.cancelled) {
      return 'Download cancelled.';
    }
    if (progress == null) {
      return 'Preparing download…';
    }
    final fraction = progress.fraction;
    if (fraction == null) {
      return '${_formatBytes(progress.receivedBytes)} downloaded';
    }
    return '${_formatBytes(progress.receivedBytes)} / ${_formatBytes(progress.totalBytes)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    filled ? AppColors.accentForeground : AppColors.onSurface,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color:
                      filled ? AppColors.accentForeground : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

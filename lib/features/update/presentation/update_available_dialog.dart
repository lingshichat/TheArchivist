import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_theme.dart';
import '../data/providers.dart';
import '../data/update_models.dart';

Future<void> showUpdateAvailableDialog({
  required BuildContext context,
  required AppUpdateInfo updateInfo,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => UpdateAvailableDialog(updateInfo: updateInfo),
  );
}

class UpdateAvailableDialog extends ConsumerWidget {
  const UpdateAvailableDialog({super.key, required this.updateInfo});

  final AppUpdateInfo updateInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(updateControllerProvider);
    final isDownloading = state.status == UpdateStatus.downloading;
    final isCancelled = state.status == UpdateStatus.cancelled;
    final isDownloaded = state.status == UpdateStatus.downloaded;
    final canInstall = state.downloadedFilePath != null &&
        state.downloadedFilePath!.isNotEmpty;
    final isInstalling = state.status == UpdateStatus.installing;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.floating),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.22),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.background.withValues(alpha: 0.55),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.system_update_alt_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Text(
                        'Update Available',
                        style: AppTextStyles.panelTitle(theme),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Current ${updateInfo.currentVersion} · Latest ${updateInfo.latestVersion}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ReleaseNotesPreview(body: updateInfo.release.body),
                if (isDownloading ||
                    isDownloaded ||
                    isInstalling ||
                    canInstall ||
                    isCancelled) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _DownloadStatus(state: state),
                ],
                if (canInstall &&
                    updateInfo.platform == UpdatePlatform.windows) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'The installer may ask you to close The Archivist before continuing.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
                if (state.message != null &&
                    (state.status == UpdateStatus.error ||
                        state.status == UpdateStatus.downloaded)) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    state.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: state.status == UpdateStatus.error
                          ? AppColors.error
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isDownloading || isInstalling
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('LATER'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    if (isDownloading)
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(updateControllerProvider.notifier)
                            .cancelDownload(),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('CANCEL'),
                      )
                    else if (canInstall)
                      FilledButton.icon(
                        onPressed: isInstalling
                            ? null
                            : () => ref
                                .read(updateControllerProvider.notifier)
                                .installDownloadedUpdate(),
                        icon:
                            const Icon(Icons.install_desktop_rounded, size: 16),
                        label: const Text('INSTALL'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: isDownloading
                            ? null
                            : () => ref
                                .read(updateControllerProvider.notifier)
                                .downloadUpdate(),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text(isDownloading ? 'DOWNLOADING' : 'DOWNLOAD'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotesPreview extends StatelessWidget {
  const _ReleaseNotesPreview({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = body.trim().isEmpty
        ? 'No release notes were provided for this version.'
        : body.trim();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 180),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.container),
      ),
      child: SingleChildScrollView(
        child: Text(
          normalized,
          style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
        ),
      ),
    );
  }
}

class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = state.progress?.fraction;
    final label = switch (state.status) {
      UpdateStatus.downloading => _formatProgress(state.progress),
      UpdateStatus.cancelled => 'Download cancelled.',
      UpdateStatus.installing => 'Opening installer…',
      UpdateStatus.downloaded => 'Download complete. Ready to install.',
      _ => state.message ?? 'Preparing update…',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: fraction,
          minHeight: 4,
          backgroundColor: AppColors.surfaceContainerHighest,
          color: AppColors.accent,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  String _formatProgress(UpdateDownloadProgress? progress) {
    if (progress == null) {
      return 'Starting download…';
    }
    final fraction = progress.fraction;
    if (fraction == null) {
      return '${_formatBytes(progress.receivedBytes)} downloaded';
    }
    final percent = (fraction * 100).clamp(0, 100).toStringAsFixed(0);
    return '$percent% · ${_formatBytes(progress.receivedBytes)} / ${_formatBytes(progress.totalBytes)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

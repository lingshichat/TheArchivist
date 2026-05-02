import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/mock_provider.dart';
import 'github_release_service.dart';
import 'providers.dart';
import 'update_installer.dart';
import 'update_mock.dart';
import 'update_models.dart';

class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState.initial();

  bool get _isMockMode => readMockMode(ref);

  GitHubReleaseService get _service => ref.read(githubReleaseServiceProvider);
  UpdateInstaller get _installer => ref.read(updateInstallerProvider);
  Future<String> get _currentVersion =>
      ref.read(currentAppVersionProvider.future);

  Future<void> checkForUpdate(UpdateCheckTrigger trigger) async {
    final previousInfo = state.updateInfo;
    final previousFilePath = state.downloadedFilePath;
    state = state.copyWith(
      status: UpdateStatus.checking,
      updateInfo: previousInfo,
      downloadedFilePath: previousFilePath,
      clearMessage: true,
      autoPromptPending: false,
    );

    try {
      if (_isMockMode) {
        await _mockCheckForUpdate(trigger);
        return;
      }

      final currentVersion = await _currentVersion;
      final updateInfo = await _service.checkForUpdate(
        currentVersion: currentVersion,
      );

      if (updateInfo == null) {
        state = UpdateState(
          status: UpdateStatus.upToDate,
          currentVersion: currentVersion,
          message: trigger == UpdateCheckTrigger.manual
              ? 'You are running the latest version.'
              : null,
        );
        return;
      }

      state = UpdateState(
        status: UpdateStatus.updateAvailable,
        currentVersion: currentVersion,
        updateInfo: updateInfo,
        message: 'Version ${updateInfo.latestVersion} is available.',
        autoPromptPending: trigger == UpdateCheckTrigger.automatic,
      );
    } on UpdateException catch (error) {
      state = UpdateState(
        status: UpdateStatus.error,
        currentVersion: state.currentVersion ?? '0.0.0',
        updateInfo: previousInfo,
        downloadedFilePath: previousFilePath,
        message: trigger == UpdateCheckTrigger.automatic ? null : error.message,
      );
    } on Object catch (error) {
      final message = error is Exception
          ? error.toString()
          : 'An unexpected error occurred.';
      state = UpdateState(
        status: UpdateStatus.error,
        currentVersion: state.currentVersion ?? '0.0.0',
        updateInfo: previousInfo,
        downloadedFilePath: previousFilePath,
        message: trigger == UpdateCheckTrigger.automatic ? null : message,
      );
    }
  }

  Future<void> downloadUpdate() async {
    final updateInfo = state.updateInfo;
    if (updateInfo == null) {
      state = state.copyWith(
        status: UpdateStatus.error,
        message: 'No update is ready to download.',
      );
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.downloading,
      progress: const UpdateDownloadProgress(receivedBytes: 0, totalBytes: 0),
      clearDownloadedFilePath: true,
      clearMessage: true,
      autoPromptPending: false,
    );

    try {
      if (_isMockMode) {
        await _mockDownloadUpdate(updateInfo);
        return;
      }

      final filePath = await _service.downloadUpdate(
        updateInfo,
        onProgress: (progress) {
          state = state.copyWith(
            status: UpdateStatus.downloading,
            progress: progress,
            clearMessage: true,
          );
        },
      );

      state = state.copyWith(
        status: UpdateStatus.downloaded,
        downloadedFilePath: filePath,
        progress: UpdateDownloadProgress(
          receivedBytes: updateInfo.asset.size > 0 ? updateInfo.asset.size : 1,
          totalBytes: updateInfo.asset.size > 0 ? updateInfo.asset.size : 1,
        ),
        message: 'Update package downloaded.',
      );
    } on UpdateDownloadCancelledException catch (error) {
      state = state.copyWith(
        status: UpdateStatus.cancelled,
        message: error.message,
        clearDownloadedFilePath: true,
      );
    } on UpdateException catch (error) {
      state = state.copyWith(
        status: UpdateStatus.error,
        message: error.message,
      );
    } on Object catch (error) {
      final message = error is Exception
          ? error.toString()
          : 'Download failed unexpectedly.';
      state = state.copyWith(
        status: UpdateStatus.error,
        message: message,
      );
    }
  }

  void cancelDownload() {
    if (_isMockMode) {
      state = state.copyWith(
        status: UpdateStatus.cancelled,
        message: 'Download cancelled.',
        clearDownloadedFilePath: true,
      );
      return;
    }
    _service.cancelActiveDownload();
  }

  Future<void> installDownloadedUpdate() async {
    final updateInfo = state.updateInfo;
    final filePath = state.downloadedFilePath;
    if (updateInfo == null || filePath == null || filePath.trim().isEmpty) {
      state = state.copyWith(
        status: UpdateStatus.error,
        message: 'Download the update before installing it.',
      );
      return;
    }

    state = state.copyWith(
      status: UpdateStatus.installing,
      clearMessage: true,
      autoPromptPending: false,
    );

    try {
      if (_isMockMode) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        state = state.copyWith(
          status: UpdateStatus.downloaded,
          message: updateInfo.platform == UpdatePlatform.windows
              ? 'Installer opened. Close The Archivist if setup asks you to.'
              : 'Android package installer opened.',
        );
        return;
      }

      await _installer.install(
        filePath: filePath,
        platform: updateInfo.platform,
      );
      state = state.copyWith(
        status: UpdateStatus.downloaded,
        message: updateInfo.platform == UpdatePlatform.windows
            ? 'Installer opened. Close The Archivist if setup asks you to.'
            : 'Android package installer opened.',
      );
    } on UpdateException catch (error) {
      state = state.copyWith(
        status: UpdateStatus.error,
        message: error.message,
      );
    } on Object catch (error) {
      final message = error is Exception
          ? error.toString()
          : 'Installation failed unexpectedly.';
      state = state.copyWith(
        status: UpdateStatus.error,
        message: message,
      );
    }
  }

  void acknowledgeAutoPrompt() {
    state = state.copyWith(autoPromptPending: false);
  }

  void reset() {
    state = const UpdateState.initial();
  }

  // --- Mock simulation ---

  Future<void> _mockCheckForUpdate(UpdateCheckTrigger trigger) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final info = UpdateMockData.updateInfo();
    state = UpdateState(
      status: UpdateStatus.updateAvailable,
      currentVersion: UpdateMockData.currentVersion,
      updateInfo: info,
      message: 'Version ${info.latestVersion} is available.',
      autoPromptPending: trigger == UpdateCheckTrigger.automatic,
    );
  }

  Future<void> _mockDownloadUpdate(AppUpdateInfo updateInfo) async {
    const total = UpdateMockData.totalBytes;
    const steps = 20;
    const stepDuration = Duration(milliseconds: 150);

    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(stepDuration);
      if (state.status != UpdateStatus.downloading) return;
      final received = (total * i / steps).round();
      state = state.copyWith(
        status: UpdateStatus.downloading,
        progress: UpdateDownloadProgress(
          receivedBytes: received,
          totalBytes: total,
        ),
        clearMessage: true,
      );
    }

    state = state.copyWith(
      status: UpdateStatus.downloaded,
      downloadedFilePath: UpdateMockData.mockDownloadPath,
      progress: const UpdateDownloadProgress(
        receivedBytes: total,
        totalBytes: total,
      ),
      message: 'Update package downloaded.',
    );
  }
}

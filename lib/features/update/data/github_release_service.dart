import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/network/github_release_api_client.dart';
import 'update_models.dart';
import 'update_version.dart';

class GitHubReleaseService {
  GitHubReleaseService(this._client);

  final GitHubReleaseApiClient _client;
  CancelToken? _activeDownloadCancelToken;

  Future<AppUpdateInfo?> checkForUpdate(
      {required String currentVersion}) async {
    final release = await _fetchLatestRelease();
    if (release.tagName.trim().isEmpty) {
      throw const UpdateNoReleaseException(
        'The latest GitHub Release does not include a version tag.',
      );
    }

    if (!isRemoteVersionNewer(
      currentVersion: currentVersion,
      remoteTag: release.tagName,
    )) {
      return null;
    }

    final platform = currentUpdatePlatform();
    if (platform == UpdatePlatform.unsupported) {
      throw const UpdateUnsupportedPlatformException(
        'Updates are currently available only on Windows and Android.',
      );
    }

    final asset = selectAssetForPlatform(release.assets, platform);
    if (asset == null || asset.browserDownloadUrl.trim().isEmpty) {
      throw UpdateNoAssetException(
        'No update package was found for ${platformLabel(platform)}.',
      );
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      release: release,
      asset: asset,
      platform: platform,
    );
  }

  Future<String> downloadUpdate(
    AppUpdateInfo updateInfo, {
    required void Function(UpdateDownloadProgress progress) onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final updateDirectory =
        Directory('${directory.path}${Platform.pathSeparator}updates');
    if (!await updateDirectory.exists()) {
      await updateDirectory.create(recursive: true);
    }

    final savePath =
        '${updateDirectory.path}${Platform.pathSeparator}${_safeFileName(updateInfo.asset.name)}';

    _activeDownloadCancelToken = CancelToken();
    try {
      await _client.download(
        updateInfo.asset.browserDownloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          onProgress(
            UpdateDownloadProgress(receivedBytes: received, totalBytes: total),
          );
        },
        cancelToken: _activeDownloadCancelToken,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.cancel) {
        throw const UpdateDownloadCancelledException('Download cancelled.');
      }
      final mapped = _mapDioException(error);
      throw UpdateDownloadException(mapped.message);
    } on FileSystemException catch (error) {
      throw UpdateDownloadException(
        error.message.isEmpty
            ? 'Unable to save the update package.'
            : error.message,
      );
    } finally {
      _activeDownloadCancelToken = null;
    }

    return savePath;
  }

  void cancelActiveDownload() {
    final token = _activeDownloadCancelToken;
    if (token == null || token.isCancelled) {
      return;
    }
    token.cancel('user_cancelled');
  }

  Future<GitHubReleaseDto> _fetchLatestRelease() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/releases/latest',
      );
      final data = response.data;
      if (data == null) {
        throw const UpdateNoReleaseException(
          'GitHub Releases returned an empty response.',
        );
      }
      return GitHubReleaseDto.fromJson(data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on TypeError {
      throw const UpdateNoReleaseException(
        'GitHub Releases returned an unexpected response format.',
      );
    }
  }

  UpdateException _mapDioException(DioException error) {
    final sourceError = error.error;
    if (sourceError is GitHubReleaseNotFoundError) {
      return UpdateNoReleaseException(sourceError.message);
    }
    if (sourceError is GitHubReleaseNetworkError ||
        sourceError is GitHubReleaseRateLimitedError ||
        sourceError is GitHubReleaseServerError) {
      return UpdateNetworkException(
          (sourceError as GitHubReleaseApiException).message);
    }
    if (sourceError is GitHubReleaseApiException) {
      return UpdateNetworkException(sourceError.message);
    }
    return const UpdateNetworkException(
      'Unable to check GitHub Releases right now.',
    );
  }

  String _safeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'TheArchivist-update-package';
    }
    return sanitized;
  }
}

UpdatePlatform currentUpdatePlatform() {
  if (Platform.isWindows) {
    return UpdatePlatform.windows;
  }
  if (Platform.isAndroid) {
    return UpdatePlatform.android;
  }
  return UpdatePlatform.unsupported;
}

String platformLabel(UpdatePlatform platform) {
  switch (platform) {
    case UpdatePlatform.windows:
      return 'Windows';
    case UpdatePlatform.android:
      return 'Android';
    case UpdatePlatform.unsupported:
      return 'this platform';
  }
}

GitHubReleaseAssetDto? selectAssetForPlatform(
  List<GitHubReleaseAssetDto> assets,
  UpdatePlatform platform,
) {
  final pattern = switch (platform) {
    UpdatePlatform.windows => RegExp(
        r'^TheArchivist-.+-setup\.exe$',
        caseSensitive: false,
      ),
    UpdatePlatform.android => RegExp(
        r'^TheArchivist-.+\.apk$',
        caseSensitive: false,
      ),
    UpdatePlatform.unsupported => null,
  };

  if (pattern == null) {
    return null;
  }

  for (final asset in assets) {
    if (pattern.hasMatch(asset.name)) {
      return asset;
    }
  }

  return null;
}

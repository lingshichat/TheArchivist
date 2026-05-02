enum UpdatePlatform { windows, android, unsupported }

enum UpdateCheckTrigger { automatic, manual }

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  updateAvailable,
  downloading,
  cancelled,
  downloaded,
  installing,
  error,
}

class GitHubReleaseAssetDto {
  const GitHubReleaseAssetDto({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  final String name;
  final String browserDownloadUrl;
  final int size;

  factory GitHubReleaseAssetDto.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAssetDto(
      name: json['name'] as String? ?? '',
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
    );
  }
}

class GitHubReleaseDto {
  const GitHubReleaseDto({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
  });

  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final List<GitHubReleaseAssetDto> assets;

  factory GitHubReleaseDto.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'];
    final assets = rawAssets is List<dynamic>
        ? rawAssets
            .whereType<Map<String, dynamic>>()
            .map(GitHubReleaseAssetDto.fromJson)
            .toList(growable: false)
        : const <GitHubReleaseAssetDto>[];

    final publishedAtValue = json['published_at'] as String?;

    return GitHubReleaseDto(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? '',
      publishedAt:
          publishedAtValue == null ? null : DateTime.tryParse(publishedAtValue),
      assets: assets,
    );
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.release,
    required this.asset,
    required this.platform,
  });

  final String currentVersion;
  final GitHubReleaseDto release;
  final GitHubReleaseAssetDto asset;
  final UpdatePlatform platform;

  String get latestVersion => release.tagName;
}

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int totalBytes;

  double? get fraction {
    if (totalBytes <= 0) {
      return null;
    }
    return receivedBytes / totalBytes;
  }
}

class UpdateState {
  const UpdateState({
    required this.status,
    required this.currentVersion,
    this.updateInfo,
    this.progress,
    this.downloadedFilePath,
    this.message,
    this.autoPromptPending = false,
  });

  const UpdateState.initial()
      : status = UpdateStatus.idle,
        currentVersion = null,
        updateInfo = null,
        progress = null,
        downloadedFilePath = null,
        message = null,
        autoPromptPending = false;

  final UpdateStatus status;
  final String? currentVersion;
  final AppUpdateInfo? updateInfo;
  final UpdateDownloadProgress? progress;
  final String? downloadedFilePath;
  final String? message;
  final bool autoPromptPending;

  UpdateState copyWith({
    UpdateStatus? status,
    String? currentVersion,
    AppUpdateInfo? updateInfo,
    UpdateDownloadProgress? progress,
    String? downloadedFilePath,
    String? message,
    bool? autoPromptPending,
    bool clearProgress = false,
    bool clearDownloadedFilePath = false,
    bool clearMessage = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      updateInfo: updateInfo ?? this.updateInfo,
      progress: clearProgress ? null : progress ?? this.progress,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : downloadedFilePath ?? this.downloadedFilePath,
      message: clearMessage ? null : message ?? this.message,
      autoPromptPending: autoPromptPending ?? this.autoPromptPending,
    );
  }
}

sealed class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class UpdateNetworkException extends UpdateException {
  const UpdateNetworkException(super.message);
}

final class UpdateNoReleaseException extends UpdateException {
  const UpdateNoReleaseException(super.message);
}

final class UpdateNoAssetException extends UpdateException {
  const UpdateNoAssetException(super.message);
}

final class UpdateDownloadException extends UpdateException {
  const UpdateDownloadException(super.message);
}

final class UpdateDownloadCancelledException extends UpdateException {
  const UpdateDownloadCancelledException(super.message);
}

final class UpdateVersionParseException extends UpdateException {
  const UpdateVersionParseException(super.message);
}

final class UpdateInstallException extends UpdateException {
  const UpdateInstallException(super.message);
}

final class UpdateVersionUnavailableException extends UpdateException {
  const UpdateVersionUnavailableException(super.message);
}

final class UpdateUnsupportedPlatformException extends UpdateException {
  const UpdateUnsupportedPlatformException(super.message);
}

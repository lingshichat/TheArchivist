import 'update_models.dart';

/// Mock update data for preview/demo mode.
///
/// Used when the global mock mode is enabled (see `mockModeProvider`).
/// Provides static factories for fake `AppUpdateInfo` and download state.
class UpdateMockData {
  static const currentVersion = '0.1.0+1';

  static final mockRelease = GitHubReleaseDto(
    tagName: 'v0.2.0',
    name: 'v0.2.0 — Feature Update',
    body:
        '## What\'s New\n\n'
        '- Added cloud sync support for WebDAV and S3\n'
        '- Improved Bangumi integration with OAuth login\n'
        '- Redesigned settings page with update notifications\n'
        '- Bug fixes and performance improvements\n\n'
        '## Breaking Changes\n\n'
        '- Local database schema migrated automatically on first launch',
    htmlUrl: 'https://github.com/example/TheArchivist/releases/tag/v0.2.0',
    publishedAt: DateTime(2026, 4, 28),
    assets: [
      GitHubReleaseAssetDto(
        name: 'TheArchivist-0.2.0-setup.exe',
        browserDownloadUrl:
            'https://github.com/example/TheArchivist/releases/download/v0.2.0/TheArchivist-0.2.0-setup.exe',
        size: 18900000,
      ),
      GitHubReleaseAssetDto(
        name: 'TheArchivist-0.2.0.apk',
        browserDownloadUrl:
            'https://github.com/example/TheArchivist/releases/download/v0.2.0/TheArchivist-0.2.0.apk',
        size: 24500000,
      ),
    ],
  );

  static AppUpdateInfo updateInfo() {
    return AppUpdateInfo(
      currentVersion: currentVersion,
      release: mockRelease,
      asset: mockRelease.assets.first,
      platform: UpdatePlatform.windows,
    );
  }

  static const totalBytes = 18900000;
  static const mockDownloadPath =
      r'C:\Users\test\AppData\Local\Temp\updates\TheArchivist-0.2.0-setup.exe';
}

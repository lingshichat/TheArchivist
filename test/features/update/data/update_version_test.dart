import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/update/data/github_release_service.dart';
import 'package:record_anywhere/features/update/data/update_models.dart';
import 'package:record_anywhere/features/update/data/update_version.dart';

void main() {
  group('AppVersion.parse', () {
    test('strips v prefix', () {
      expect(AppVersion.parse('v1.2.3').parts, [1, 2, 3]);
      expect(AppVersion.parse('V1.2.3').parts, [1, 2, 3]);
    });

    test('strips build metadata after +', () {
      expect(AppVersion.parse('0.1.0+1').parts, [0, 1, 0]);
      expect(AppVersion.parse('2.0.0+42').parts, [2, 0, 0]);
    });

    test('strips pre-release after -', () {
      expect(AppVersion.parse('1.0.0-beta').parts, [1, 0, 0]);
      expect(AppVersion.parse('1.0.0-rc.1').parts, [1, 0, 0]);
    });

    test('throws typed error for empty or invalid input', () {
      expect(
        () => AppVersion.parse(''),
        throwsA(isA<UpdateVersionParseException>()),
      );
      expect(
        () => AppVersion.parse('abc'),
        throwsA(isA<UpdateVersionParseException>()),
      );
      expect(
        () => AppVersion.parse('v'),
        throwsA(isA<UpdateVersionParseException>()),
      );
    });

    test('handles single and double part versions', () {
      expect(AppVersion.parse('1').parts, [1]);
      expect(AppVersion.parse('1.2').parts, [1, 2]);
    });
  });

  group('AppVersion.compareTo', () {
    test('compares equal versions', () {
      expect(AppVersion.parse('1.2.3').compareTo(AppVersion.parse('1.2.3')), 0);
      expect(AppVersion.parse('1.2').compareTo(AppVersion.parse('1.2.0')), 0);
    });

    test('compares different lengths by padding with zeros', () {
      expect(AppVersion.parse('1.2').compareTo(AppVersion.parse('1.2.3')), -1);
      expect(AppVersion.parse('1.2.3').compareTo(AppVersion.parse('1.2')), 1);
    });

    test('compares major version differences', () {
      expect(AppVersion.parse('2.0.0').compareTo(AppVersion.parse('1.9.9')), 1);
      expect(
          AppVersion.parse('1.0.0').compareTo(AppVersion.parse('2.0.0')), -1);
    });

    test('compares minor version differences', () {
      expect(AppVersion.parse('1.2.0').compareTo(AppVersion.parse('1.1.9')), 1);
      expect(
          AppVersion.parse('1.1.0').compareTo(AppVersion.parse('1.2.0')), -1);
    });

    test('compares patch version differences', () {
      expect(AppVersion.parse('1.0.1').compareTo(AppVersion.parse('1.0.0')), 1);
      expect(
          AppVersion.parse('1.0.0').compareTo(AppVersion.parse('1.0.1')), -1);
    });
  });

  group('isRemoteVersionNewer', () {
    test('handles release tags with v prefix and local build metadata', () {
      expect(
        isRemoteVersionNewer(currentVersion: '0.1.0+1', remoteTag: 'v0.2.0'),
        isTrue,
      );
      expect(
        isRemoteVersionNewer(currentVersion: '0.1.0+1', remoteTag: 'v0.1.0'),
        isFalse,
      );
    });

    test('returns false when versions are equal', () {
      expect(
        isRemoteVersionNewer(currentVersion: '1.0.0', remoteTag: 'v1.0.0'),
        isFalse,
      );
      expect(
        isRemoteVersionNewer(currentVersion: '1.0.0+5', remoteTag: 'v1.0.0'),
        isFalse,
      );
    });

    test('returns true when remote is newer', () {
      expect(
        isRemoteVersionNewer(currentVersion: '0.9.0', remoteTag: 'v1.0.0'),
        isTrue,
      );
      expect(
        isRemoteVersionNewer(currentVersion: '1.0.0', remoteTag: 'v1.0.1'),
        isTrue,
      );
    });

    test('returns false when remote is older', () {
      expect(
        isRemoteVersionNewer(currentVersion: '1.0.0', remoteTag: 'v0.9.0'),
        isFalse,
      );
      expect(
        isRemoteVersionNewer(currentVersion: '1.1.0', remoteTag: 'v1.0.5'),
        isFalse,
      );
    });
  });

  group('selectAssetForPlatform', () {
    const assets = <GitHubReleaseAssetDto>[
      GitHubReleaseAssetDto(
        name: 'TheArchivist-v0.2.0-setup.exe',
        browserDownloadUrl: 'https://example.com/windows.exe',
        size: 42,
      ),
      GitHubReleaseAssetDto(
        name: 'TheArchivist-v0.2.0.apk',
        browserDownloadUrl: 'https://example.com/android.apk',
        size: 24,
      ),
    ];

    test('matches Windows installer asset', () {
      final asset = selectAssetForPlatform(assets, UpdatePlatform.windows);

      expect(asset?.name, 'TheArchivist-v0.2.0-setup.exe');
    });

    test('matches Android APK asset', () {
      final asset = selectAssetForPlatform(assets, UpdatePlatform.android);

      expect(asset?.name, 'TheArchivist-v0.2.0.apk');
    });

    test('returns null for unsupported platform', () {
      final asset = selectAssetForPlatform(assets, UpdatePlatform.unsupported);

      expect(asset, isNull);
    });

    test('returns null when no matching asset exists', () {
      const noMatchAssets = <GitHubReleaseAssetDto>[
        GitHubReleaseAssetDto(
          name: 'source.zip',
          browserDownloadUrl: 'https://example.com/source.zip',
          size: 10,
        ),
      ];

      expect(
        selectAssetForPlatform(noMatchAssets, UpdatePlatform.windows),
        isNull,
      );
      expect(
        selectAssetForPlatform(noMatchAssets, UpdatePlatform.android),
        isNull,
      );
    });

    test('is case-insensitive for asset names', () {
      const mixedCaseAssets = <GitHubReleaseAssetDto>[
        GitHubReleaseAssetDto(
          name: 'thearchivist-v0.2.0-setup.EXE',
          browserDownloadUrl: 'https://example.com/windows.exe',
          size: 42,
        ),
        GitHubReleaseAssetDto(
          name: 'TheArchivist-v0.2.0.APK',
          browserDownloadUrl: 'https://example.com/android.apk',
          size: 24,
        ),
      ];

      expect(
        selectAssetForPlatform(mixedCaseAssets, UpdatePlatform.windows)?.name,
        'thearchivist-v0.2.0-setup.EXE',
      );
      expect(
        selectAssetForPlatform(mixedCaseAssets, UpdatePlatform.android)?.name,
        'TheArchivist-v0.2.0.APK',
      );
    });
  });

  group('currentUpdatePlatform', () {
    test('returns a valid platform value', () {
      final platform = currentUpdatePlatform();
      expect(
        platform,
        isA<UpdatePlatform>(),
      );
    });
  });

  group('platformLabel', () {
    test('returns correct labels', () {
      expect(platformLabel(UpdatePlatform.windows), 'Windows');
      expect(platformLabel(UpdatePlatform.android), 'Android');
      expect(platformLabel(UpdatePlatform.unsupported), 'this platform');
    });
  });
}

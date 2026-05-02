import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../shared/network/github_release_api_client.dart';
import 'github_release_service.dart';
import 'update_controller.dart';
import 'update_installer.dart';
import 'update_models.dart';

export '../../../shared/providers/mock_provider.dart' show mockModeProvider;

final currentAppVersionProvider = FutureProvider<String>((ref) async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  } on MissingPluginException {
    throw const UpdateVersionUnavailableException(
      'Unable to read the current app version.',
    );
  } on PlatformException catch (error) {
    throw UpdateVersionUnavailableException(
      error.message ?? 'Unable to read the current app version.',
    );
  }
});

final githubReleaseUserAgentProvider =
    Provider<Future<String> Function()>((ref) {
  return GitHubReleaseApiClient.defaultUserAgent;
});

final githubReleaseApiClientProvider = Provider<GitHubReleaseApiClient>((ref) {
  return GitHubReleaseApiClient(
    userAgentProvider: ref.watch(githubReleaseUserAgentProvider),
  );
});

final githubReleaseServiceProvider = Provider<GitHubReleaseService>((ref) {
  return GitHubReleaseService(ref.watch(githubReleaseApiClientProvider));
});

final updateInstallerProvider = Provider<UpdateInstaller>((ref) {
  return const PlatformUpdateInstaller();
});

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

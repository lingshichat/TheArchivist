import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/data/providers.dart';
import '../../../shared/network/bangumi_api_client.dart';
import 'bangumi_api_service.dart';
import 'bangumi_auth.dart';
import 'bangumi_auth_controller.dart';
import 'bangumi_auth_verifier.dart';
import 'bangumi_oauth_config.dart';
import 'bangumi_oauth_service.dart';
import 'bangumi_progress_sync_service.dart';
import 'bangumi_pull_service.dart';
import 'bangumi_sync_feedback.dart';
import 'bangumi_sync_service.dart';
import 'bangumi_sync_status.dart';
import 'bangumi_token_store.dart';

final bangumiTokenStoreProvider = Provider<BangumiTokenStore>((ref) {
  return SecureBangumiTokenStore();
});

final bangumiTokenProvider = Provider<Future<String?> Function()>((ref) {
  return ref.watch(bangumiTokenStoreProvider).read;
});

final bangumiUserAgentProvider = Provider<Future<String> Function()>((ref) {
  return BangumiApiClient.defaultUserAgent;
});

final bangumiApiClientProvider = Provider<BangumiApiClient>((ref) {
  return BangumiApiClient(
    tokenProvider: ref.watch(bangumiTokenProvider),
    userAgentProvider: ref.watch(bangumiUserAgentProvider),
  );
});

final bangumiApiServiceProvider = Provider<BangumiApiService>((ref) {
  return BangumiApiService(ref.watch(bangumiApiClientProvider));
});

final bangumiAuthVerifierProvider = Provider<BangumiAuthVerifier>((ref) {
  return BangumiApiAuthVerifier(
    userAgentProvider: ref.watch(bangumiUserAgentProvider),
  );
});

final bangumiOAuthConfigProvider = Provider<BangumiOAuthConfig?>((ref) {
  return BangumiOAuthConfig.tryFromEnvironment();
});

final bangumiExternalUrlLauncherProvider =
    Provider<Future<bool> Function(Uri uri)>((ref) {
      return (uri) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      };
    });

final bangumiOAuthServiceProvider = Provider<BangumiOAuthService?>((ref) {
  final config = ref.watch(bangumiOAuthConfigProvider);
  if (config == null) {
    return null;
  }

  return BangumiBrowserOAuthService(
    config: config,
    launchExternalUrl: ref.watch(bangumiExternalUrlLauncherProvider),
  );
});

final bangumiSyncFeedbackProvider =
    NotifierProvider<BangumiSyncFeedbackController, BangumiSyncFeedbackEvent?>(
      BangumiSyncFeedbackController.new,
    );

final bangumiAuthProvider =
    AsyncNotifierProvider<BangumiAuthController, BangumiAuth?>(
      BangumiAuthController.new,
    );

final bangumiPullServiceProvider = Provider<BangumiPullService>((ref) {
  return BangumiCollectionPullService(
    apiService: ref.watch(bangumiApiServiceProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    userEntryRepository: ref.watch(userEntryRepositoryProvider),
    progressRepository: ref.watch(progressRepositoryProvider),
  );
});

final bangumiSyncStatusProvider =
    StateNotifierProvider<BangumiSyncStatusController, BangumiSyncStatusState>((
      ref,
    ) {
      return BangumiSyncStatusController(
        pullService: ref.watch(bangumiPullServiceProvider),
        feedbackController: ref.watch(bangumiSyncFeedbackProvider.notifier),
      );
    });

final bangumiSyncServiceProvider = Provider<BangumiSyncService>((ref) {
  return BangumiCollectionSyncService(
    apiService: ref.watch(bangumiApiServiceProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    userEntryRepository: ref.watch(userEntryRepositoryProvider),
    tokenStore: ref.watch(bangumiTokenStoreProvider),
    feedbackController: ref.watch(bangumiSyncFeedbackProvider.notifier),
    onUnauthorized: ref.watch(bangumiAuthProvider.notifier).invalidateSession,
  );
});

final bangumiProgressSyncServiceProvider =
    Provider<BangumiProgressSyncService>((ref) {
      return BangumiProgressSyncServiceImpl(
        apiService: ref.watch(bangumiApiServiceProvider),
        mediaRepository: ref.watch(mediaRepositoryProvider),
        progressRepository: ref.watch(progressRepositoryProvider),
        tokenStore: ref.watch(bangumiTokenStoreProvider),
        feedbackController: ref.watch(bangumiSyncFeedbackProvider.notifier),
        onUnauthorized: ref.watch(bangumiAuthProvider.notifier).invalidateSession,
      );
    });

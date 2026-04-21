import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/network/bangumi_api_client.dart';
import 'bangumi_api_service.dart';

final bangumiTokenProvider = Provider<Future<String?> Function()>((ref) {
  return BangumiApiClient.alwaysNullTokenProvider;
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

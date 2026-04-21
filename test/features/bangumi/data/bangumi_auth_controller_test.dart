import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_auth.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_auth_verifier.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_sync_status.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_token_store.dart';
import 'package:record_anywhere/features/bangumi/data/providers.dart';
import 'package:record_anywhere/shared/network/bangumi_api_client.dart';

void main() {
  test('auth provider returns null when no token is stored', () async {
    final container = ProviderContainer(
      overrides: [
        bangumiTokenStoreProvider.overrideWithValue(
          InMemoryBangumiTokenStore(),
        ),
        bangumiAuthVerifierProvider.overrideWithValue(
          _FakeBangumiAuthVerifier(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final auth = await container.read(bangumiAuthProvider.future);

    expect(auth, isNull);
  });

  test('auth provider restores a stored token into BangumiAuth', () async {
    final verifier = _FakeBangumiAuthVerifier(
      auth: const BangumiAuth(
        userId: 1,
        username: 'ikari',
        displayName: 'Shinji Ikari',
      ),
    );
    final pullService = _FakeBangumiPullService();

    final container = ProviderContainer(
      overrides: [
        bangumiTokenStoreProvider.overrideWithValue(
          InMemoryBangumiTokenStore(token: 'stored-token'),
        ),
        bangumiAuthVerifierProvider.overrideWithValue(verifier),
        bangumiPullServiceProvider.overrideWithValue(pullService),
      ],
    );
    addTearDown(container.dispose);

    final auth = await container.read(bangumiAuthProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(auth, isNotNull);
    expect(auth!.displayName, 'Shinji Ikari');
    expect(verifier.tokens, ['stored-token']);
    expect(pullService.calls, hasLength(1));
    expect(pullService.calls.single.trigger, BangumiSyncTrigger.startupRestore);
    expect(pullService.calls.single.username, 'ikari');
  });

  test(
    'auth provider clears stored token when verification is unauthorized',
    () async {
      final store = InMemoryBangumiTokenStore(token: 'expired-token');
      final verifier = _FakeBangumiAuthVerifier(
        error: const BangumiUnauthorizedError('expired'),
      );

      final container = ProviderContainer(
        overrides: [
          bangumiTokenStoreProvider.overrideWithValue(store),
          bangumiAuthVerifierProvider.overrideWithValue(verifier),
        ],
      );
      addTearDown(container.dispose);

      final auth = await container.read(bangumiAuthProvider.future);

      expect(auth, isNull);
      expect(await store.read(), isNull);
    },
  );

  test('connect validates token, stores it, and updates state', () async {
    final store = InMemoryBangumiTokenStore();
    final verifier = _FakeBangumiAuthVerifier(
      auth: const BangumiAuth(
        userId: 2,
        username: 'misato',
        displayName: 'Misato Katsuragi',
      ),
    );
    final pullService = _FakeBangumiPullService();

    final container = ProviderContainer(
      overrides: [
        bangumiTokenStoreProvider.overrideWithValue(store),
        bangumiAuthVerifierProvider.overrideWithValue(verifier),
        bangumiPullServiceProvider.overrideWithValue(pullService),
      ],
    );
    addTearDown(container.dispose);

    await container.read(bangumiAuthProvider.future);
    await container.read(bangumiAuthProvider.notifier).connect('new-token');
    await Future<void>.delayed(Duration.zero);

    final auth = container.read(bangumiAuthProvider).valueOrNull;
    expect(auth, isNotNull);
    expect(auth!.username, 'misato');
    expect(await store.read(), 'new-token');
    expect(verifier.tokens, ['new-token']);
    expect(pullService.calls, hasLength(1));
    expect(pullService.calls.single.trigger, BangumiSyncTrigger.postConnect);
    expect(pullService.calls.single.username, 'misato');
  });

  test('disconnect clears stored token and resets auth state', () async {
    final store = InMemoryBangumiTokenStore(token: 'stored-token');
    final verifier = _FakeBangumiAuthVerifier(
      auth: const BangumiAuth(
        userId: 3,
        username: 'rei',
        displayName: 'Rei Ayanami',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        bangumiTokenStoreProvider.overrideWithValue(store),
        bangumiAuthVerifierProvider.overrideWithValue(verifier),
      ],
    );
    addTearDown(container.dispose);

    await container.read(bangumiAuthProvider.future);
    await container.read(bangumiAuthProvider.notifier).disconnect();

    expect(container.read(bangumiAuthProvider).valueOrNull, isNull);
    expect(await store.read(), isNull);
  });
}

class _FakeBangumiAuthVerifier implements BangumiAuthVerifier {
  _FakeBangumiAuthVerifier({this.auth, this.error});

  final BangumiAuth? auth;
  final Object? error;
  final List<String> tokens = <String>[];

  @override
  Future<BangumiAuth> verifyToken(String token) async {
    tokens.add(token);
    if (error != null) {
      throw error!;
    }
    return auth ??
        const BangumiAuth(
          userId: 99,
          username: 'test-user',
          displayName: 'Test User',
        );
  }
}

class _FakeBangumiPullService implements BangumiPullService {
  final List<_PullCall> calls = <_PullCall>[];

  @override
  Future<BangumiPullSummary> pullCollections({
    required String username,
    required BangumiSyncTrigger trigger,
  }) async {
    calls.add(_PullCall(username: username, trigger: trigger));
    return const BangumiPullSummary(
      importedCount: 0,
      updatedCount: 0,
      skippedCount: 0,
      localWinsCount: 0,
      failedCount: 0,
    );
  }
}

class _PullCall {
  const _PullCall({required this.username, required this.trigger});

  final String username;
  final BangumiSyncTrigger trigger;
}

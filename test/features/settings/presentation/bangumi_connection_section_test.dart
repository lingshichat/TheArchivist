import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_auth.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_auth_verifier.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_oauth_service.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_sync_status.dart';
import 'package:record_anywhere/features/bangumi/data/bangumi_token_store.dart';
import 'package:record_anywhere/features/bangumi/data/providers.dart';
import 'package:record_anywhere/features/settings/presentation/bangumi_connection_section.dart';
import 'package:record_anywhere/shared/theme/app_theme.dart';

void main() {
  testWidgets('section verifies token and switches to connected state', (
    tester,
  ) async {
    final store = InMemoryBangumiTokenStore();
    final verifier = _FakeBangumiAuthVerifier(
      auth: const BangumiAuth(
        userId: 1,
        username: 'misato',
        displayName: 'Misato Katsuragi',
      ),
    );
    final pullService = _FakeBangumiPullService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bangumiTokenStoreProvider.overrideWithValue(store),
          bangumiAuthVerifierProvider.overrideWithValue(verifier),
          bangumiPullServiceProvider.overrideWithValue(pullService),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BangumiConnectionSection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Verify and Connect'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fresh-token');
    await tester.tap(find.text('Verify and Connect'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Misato Katsuragi'), findsOneWidget);
    expect(find.text('@misato'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(await store.read(), 'fresh-token');
    expect(verifier.tokens, ['fresh-token']);
    expect(pullService.calls, hasLength(1));
    expect(pullService.calls.single.trigger, BangumiSyncTrigger.postConnect);
  });

  testWidgets('section restores stored auth and can disconnect', (
    tester,
  ) async {
    final store = InMemoryBangumiTokenStore(token: 'stored-token');
    final verifier = _FakeBangumiAuthVerifier(
      auth: const BangumiAuth(
        userId: 2,
        username: 'rei',
        displayName: 'Rei Ayanami',
      ),
    );
    final pullService = _FakeBangumiPullService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bangumiTokenStoreProvider.overrideWithValue(store),
          bangumiAuthVerifierProvider.overrideWithValue(verifier),
          bangumiPullServiceProvider.overrideWithValue(pullService),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BangumiConnectionSection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rei Ayanami'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);

    await tester.tap(find.text('Disconnect'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Verify and Connect'), findsOneWidget);
    expect(await store.read(), isNull);
    expect(verifier.tokens, ['stored-token']);
    expect(pullService.calls, hasLength(1));
    expect(pullService.calls.single.trigger, BangumiSyncTrigger.startupRestore);
  });

  testWidgets('section can connect through browser OAuth flow', (tester) async {
    final store = InMemoryBangumiTokenStore();
    final verifier = _FakeBangumiAuthVerifier(
      auth: const BangumiAuth(
        userId: 3,
        username: 'asuka',
        displayName: 'Asuka Langley',
      ),
    );
    final oauthService = _FakeBangumiOAuthService(token: 'oauth-token');
    final pullService = _FakeBangumiPullService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bangumiTokenStoreProvider.overrideWithValue(store),
          bangumiAuthVerifierProvider.overrideWithValue(verifier),
          bangumiOAuthServiceProvider.overrideWithValue(oauthService),
          bangumiPullServiceProvider.overrideWithValue(pullService),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BangumiConnectionSection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sign in with Browser'), findsOneWidget);

    await tester.tap(find.text('Sign in with Browser'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(oauthService.calls, 1);
    expect(find.text('Asuka Langley'), findsOneWidget);
    expect(await store.read(), 'oauth-token');
    expect(verifier.tokens, ['oauth-token']);
    expect(pullService.calls, hasLength(1));
    expect(pullService.calls.single.trigger, BangumiSyncTrigger.postConnect);
  });

  testWidgets('section enables browser OAuth with built-in desktop config', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bangumiTokenStoreProvider.overrideWithValue(
            InMemoryBangumiTokenStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BangumiConnectionSection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Browser login is enabled for this desktop build.'),
      findsOneWidget,
    );

    final browserLoginButton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Sign in with Browser'),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ),
    );
    expect(browserLoginButton.onPressed, isNotNull);
  });

  testWidgets('section can trigger manual sync and render sync summary', (
    tester,
  ) async {
    final store = InMemoryBangumiTokenStore(token: 'stored-token');
    final verifier = _FakeBangumiAuthVerifier(
      auth: const BangumiAuth(
        userId: 4,
        username: 'kaji',
        displayName: 'Ryoji Kaji',
      ),
    );
    final pullService = _FakeBangumiPullService(
      summaries: <BangumiPullSummary>[
        const BangumiPullSummary(
          importedCount: 1,
          updatedCount: 0,
          skippedCount: 0,
          localWinsCount: 0,
          failedCount: 0,
        ),
        const BangumiPullSummary(
          importedCount: 2,
          updatedCount: 1,
          skippedCount: 3,
          localWinsCount: 1,
          failedCount: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bangumiTokenStoreProvider.overrideWithValue(store),
          bangumiAuthVerifierProvider.overrideWithValue(verifier),
          bangumiPullServiceProvider.overrideWithValue(pullService),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: BangumiConnectionSection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Imported 1'), findsOneWidget);

    await tester.tap(find.text('Sync now'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(pullService.calls, hasLength(2));
    expect(pullService.calls.last.trigger, BangumiSyncTrigger.manual);
    expect(find.textContaining('Imported 2'), findsOneWidget);
    expect(find.textContaining('Updated 1'), findsOneWidget);
  });
}

class _FakeBangumiAuthVerifier implements BangumiAuthVerifier {
  _FakeBangumiAuthVerifier({required this.auth});

  final BangumiAuth auth;
  final List<String> tokens = <String>[];

  @override
  Future<BangumiAuth> verifyToken(String token) async {
    tokens.add(token);
    return auth;
  }
}

class _FakeBangumiOAuthService implements BangumiOAuthService {
  _FakeBangumiOAuthService({required this.token});

  final String token;
  int calls = 0;

  @override
  Future<String> authorize() async {
    calls += 1;
    return token;
  }
}

class _FakeBangumiPullService implements BangumiPullService {
  _FakeBangumiPullService({List<BangumiPullSummary>? summaries})
    : _summaries =
          summaries ??
          <BangumiPullSummary>[
            const BangumiPullSummary(
              importedCount: 0,
              updatedCount: 0,
              skippedCount: 0,
              localWinsCount: 0,
              failedCount: 0,
            ),
          ];

  final List<BangumiPullSummary> _summaries;
  final List<_PullCall> calls = <_PullCall>[];

  @override
  Future<BangumiPullSummary> pullCollections({
    required String username,
    required BangumiSyncTrigger trigger,
  }) async {
    calls.add(_PullCall(username: username, trigger: trigger));
    final index = calls.length - 1;
    if (index >= _summaries.length) {
      return _summaries.last;
    }
    return _summaries[index];
  }
}

class _PullCall {
  const _PullCall({required this.username, required this.trigger});

  final String username;
  final BangumiSyncTrigger trigger;
}

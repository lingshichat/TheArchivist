# Network Guidelines

> How HTTP/networking is done in this project.

---

## Overview

This project uses `dio ^5.x` as the HTTP client. All external API integrations
follow the same layered structure: **ApiClient → ApiService → Provider**.

The first integration is Bangumi; the same pattern applies to future integrations.

---

## Architecture Layers

```
shared/network/          ← transport concerns (dio instance, interceptors, base config)
  bangumi_api_client.dart

features/<integration>/data/  ← integration-specific logic
  bangumi_api_service.dart    ← typed methods calling the client
  bangumi_models.dart         ← request/response DTOs
  bangumi_type_mapper.dart    ← external ↔ local enum mapping
  providers.dart              ← Riverpod providers for this integration
```

Rules:

- `shared/network/` owns the `Dio` instance and global interceptors
- `features/<integration>/data/` owns everything specific to one API
- Pages and controllers **never** import `dio` directly

---

## ApiClient Conventions

Each external API gets one `ApiClient` class in `shared/network/`.

```dart
class BangumiApiClient {
  final Dio _dio;

  BangumiApiClient({
    String baseUrl = 'https://api.bgm.tv',
    Future<String?> Function()? tokenProvider,
    String userAgent = 'record-anywhere/0.1.0 (...)',
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 15),
  }) : _dio = Dio(BaseOptions(
         baseUrl: baseUrl,
         connectTimeout: connectTimeout,
         receiveTimeout: receiveTimeout,
         headers: {
           'User-Agent': userAgent,
           'Accept': 'application/json',
         },
       )) {
    _dio.interceptors.add(/* token interceptor */);
    _dio.interceptors.add(/* error mapping interceptor */);
  }
}
```

Mandatory:

- **User-Agent**: `{appname}/{version} ({contact})`. Missing UA causes 412 from Bangumi.
  Read version from `PackageInfo` in production; inject fixed string in tests.
- **Accept**: `application/json` as default header
- **Timeout**: connect 10s, receive 15s (override per-request when needed)
- **Token injection**: via `Future<String?> Function() tokenProvider` callback.
  The interceptor calls this on every request; returns `null` for unauthenticated calls.
  Never store tokens in the ApiClient itself.
- **Error mapping interceptor**: catches `DioException` and throws typed
  sealed-class exceptions (see Error Handling section)

---

## ApiService Conventions

The service wraps typed methods over the client.

```dart
class BangumiApiService {
  final BangumiApiClient _client;
  const BangumiApiService(this._client);

  Future<BangumiSearchResult> searchSubjects(String keyword, {/* filters */});
  Future<BangumiSubjectDto> getSubject(int id);
  Future<BangumiUserDto> getMe();
  Future<void> updateCollection(int subjectId, {/* fields */});
  // ...
}
```

Rules:

- Methods return domain DTOs, not raw `Response` objects
- Methods are `async`/`Future`-based; no streams for HTTP calls
- Service methods wrap transport calls and rethrow `BangumiApiException`
  before returning to controllers/UI; `DioException` must not escape even if an
  interceptor path is bypassed in tests or edge cases
- Caching belongs in the service layer, not the client layer
  - Simple in-memory cache: `Map<K, (V, DateTime)>` with TTL check
  - Do not pull in `dio_cache_interceptor` or similar packages without team consensus
- Retry logic is **not** in the service — failures propagate to the caller

---

## Error Handling (Network Layer)

All HTTP errors are mapped to a **sealed class** hierarchy before leaving the
network layer. Controllers and UI pattern-match on the sealed type.

```
BangumiApiException (sealed)
├── BangumiNetworkError       — connection timeout, DNS failure, no network
├── BangumiUnauthorizedError  — 401, 403
├── BangumiNotFoundError      — 404
├── BangumiBadRequestError    — 400, 412 (e.g. missing User-Agent)
├── BangumiServerError        — 5xx, 429
└── BangumiUnknownError       — anything else
```

Rules:

- The error mapping interceptor in `ApiClient` does the `DioException → SealedException` conversion
- Subclasses carry relevant fields (`statusCode`, optional `responseBody`)
- UI/controllers use `switch` on the sealed type for exhaustive handling
- Never expose `DioException` outside the network layer

---

## Testing Network Code

Use `http_mock_adapter` for unit tests of `ApiService` methods.

Rules:

- Mock at the `Dio` level via `DioAdapter`
- Test both success parsing and error mapping paths
- Test TTL cache expiry with fake timers
- Token provider is always injectable — use `() async => null` for unauthenticated tests

```dart
test('searchSubjects returns parsed results', () async {
  final dio = Dio();
  final adapter = DioAdapter(dio: dio);
  adapter.onPost('/v0/search/subjects', ...);
  final service = BangumiApiService(BangumiApiClient(/* test config */));
  final result = await service.searchSubjects('test');
  expect(result.total, greaterThan(0));
});
```

---

## Adding a New Integration

When adding a new external API (e.g. TMDB, WebDAV):

1. Create `shared/network/<name>_api_client.dart`
2. Create `features/<name>/data/` with service, models, mapper, providers
3. Follow the same sealed-class error pattern
4. Register providers in `features/<name>/data/providers.dart`
5. Import from feature controllers — never from shared/network directly in UI

---

## Forbidden Patterns

- Importing `package:dio/dio.dart` in UI or controller files
- Storing tokens/passwords in ApiClient constructor params (use callback)
- Using `dio` interceptors for business logic (they are for transport concerns only)
- Pulling in cache/retry interceptor packages without updating this guideline first
- Making HTTP calls in widget `build()` methods
- Hard-coding API URLs outside of ApiClient constructors

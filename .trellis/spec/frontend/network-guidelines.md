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
  Future<List<BangumiCollectionDto>> listCollections(String username, {/* paging/filter */});
  Future<void> updateCollection(int subjectId, {/* fields */});
  Future<BangumiCollectionDto> getCollection(String username, int subjectId);
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

## Scenario: Bangumi subject search and detail fetch

### 1. Scope / Trigger

- Trigger: `/add` needs Bangumi search, infinite-scroll pagination, and a
  pre-add detail preview dialog.
- This is cross-layer because the same request contract flows through
  `BangumiApiService` → Riverpod provider → Add page UI state.

### 2. Signatures

```dart
Future<BangumiSearchResult> searchSubjects(
  String keyword, {
  Map<String, Object?>? filter,
  int limit = 20,
  int offset = 0,
});

Future<BangumiSubjectDto> getSubject(int id);
```

### 3. Contracts

- `searchSubjects(...)`
  - endpoint: `POST /v0/search/subjects`
  - request body:
    - `keyword`: trimmed non-empty string
    - `filter`: optional map; Bangumi type filters belong here
  - query params:
    - `limit`: clamp to `1..50`
    - `offset`: negative values normalize to `0`
  - Add-page default page size is `20`
  - Add-page "All" type filter must map to `type: [1, 2, 4, 6]`
    and must exclude `music=3`
  - response DTO must preserve:
    - `total`
    - `data`
    - `limit`
    - `offset`

- `getSubject(int id)`
  - endpoint: `GET /v0/subjects/{id}`
  - input must be a positive integer id
  - service owns subject-detail cache
  - current cache contract:
    - in-memory cache keyed by subject id
    - TTL: `300s`
    - concurrent requests for the same subject share one pending future

### 4. Validation & Error Matrix

| Input / State | Expected Result | Error Surface |
|---------------|-----------------|---------------|
| `keyword.trim().isEmpty` | reject request before HTTP | `ArgumentError` |
| `limit < 1` or `limit > 50` | normalize in service | no UI error |
| `offset < 0` | normalize to `0` | no UI error |
| `id <= 0` in `getSubject` | reject before HTTP | `ArgumentError` |
| Bangumi `400 / 412` | typed request failure | `BangumiBadRequestError` |
| Bangumi `401 / 403` | typed auth failure | `BangumiUnauthorizedError` |
| network / timeout | typed transport failure | `BangumiNetworkError` |

### 5. Good / Base / Bad Cases

- Good:
  - keyword `"eva"`, `type: [2]`, `limit: 20`, `offset: 20`
  - returns page 2 and appends safely in UI
- Base:
  - keyword `"haruhi"`, no explicit `limit/offset`
  - service uses default first page contract
- Bad:
  - keyword `"   "`
  - `getSubject(0)`
  - provider or page trying to fetch `music=3` from the Add-page filter set

### 6. Tests Required

- Service tests:
  - `searchSubjects` preserves `total/data/limit/offset`
  - `searchSubjects` passes `type: [1, 2, 4, 6]` for Add-page all-filter flows
  - `getSubject` returns cached subject within TTL
  - concurrent `getSubject(id)` calls do not duplicate HTTP requests
- Assertion points:
  - page 1 + page 2 merge without missing `offset`
  - invalid keyword/id fails before transport
  - typed `BangumiApiException` subclasses escape, not `DioException`

### 7. Wrong vs Correct

#### Wrong

```dart
Future<List<dynamic>> search(String keyword) async {
  final response = await dio.post('/v0/search/subjects', data: {'keyword': keyword});
  return response.data['data'] as List<dynamic>;
}
```

- loses `total/limit/offset`
- exposes transport details to callers
- no pagination contract

#### Correct

```dart
Future<BangumiSearchResult> searchSubjects(
  String keyword, {
  Map<String, Object?>? filter,
  int limit = 20,
  int offset = 0,
}) async {
  final normalizedKeyword = keyword.trim();
  if (normalizedKeyword.isEmpty) {
    throw ArgumentError.value(keyword, 'keyword');
  }

  final response = await _client.post<Map<String, dynamic>>(
    '/v0/search/subjects',
    queryParameters: <String, dynamic>{
      'limit': limit.clamp(1, 50),
      'offset': offset < 0 ? 0 : offset,
    },
    data: <String, Object?>{
      'keyword': normalizedKeyword,
      if (filter != null && filter.isNotEmpty) 'filter': filter,
    },
  );

  return BangumiSearchResult.fromJson(
    Map<String, Object?>.from(response.data ?? const <String, Object?>{}),
  );
}
```

## Scenario: Bangumi collection pull for post-connect / startup / manual sync

### 1. Scope / Trigger

- Trigger: Bangumi binding now includes collection import after connect,
  background reconciliation after startup restore, and manual `Sync now`.
- This is cross-layer because one request contract flows through
  `BangumiApiService` → Bangumi pull service → local merge logic → settings-page
  summary state.

### 2. Signatures

```dart
Future<List<BangumiCollectionDto>> listCollections(
  String username, {
  int limit = 30,
  int offset = 0,
  List<int>? subjectTypes,
});

Future<BangumiCollectionDto> getCollection(String username, int subjectId);
```

### 3. Contracts

- `listCollections(...)`
  - endpoint: `GET /v0/users/{username}/collections`
  - input:
    - `username`: trimmed non-empty string
    - `limit`: normalized to a safe positive page size
    - `offset`: negative values normalize to `0`
    - `subjectTypes`: current phase allows only Bangumi subject types
      `1 / 2 / 4 / 6`
  - current phase contract:
    - exclude `music=3`
    - preserve collection row fields:
      - `subjectId`
      - `type`
      - `rate`
      - `updatedAt`
      - optional embedded `subject`
  - service may return a typed page list even if the API omits some subject
    fields; callers are allowed to follow up with `getSubject(id)` to hydrate
    metadata for local item creation

- `getCollection(username, subjectId)`
  - endpoint: `GET /v0/users/{username}/collections/{id}`
  - used for subject-specific reconciliation or targeted refresh

### 4. Validation & Error Matrix

| Input / State | Expected Result | Error Surface |
|---------------|-----------------|---------------|
| `username.trim().isEmpty` | reject before HTTP | `ArgumentError` |
| `limit <= 0` | normalize in service | no UI error |
| `offset < 0` | normalize to `0` | no UI error |
| unsupported subject type in filter | reject before HTTP | `ArgumentError` |
| Bangumi `401 / 403` | typed auth failure | `BangumiUnauthorizedError` |
| Bangumi `404` for one collection | typed missing-row failure | `BangumiNotFoundError` |
| network / timeout during page pull | typed transport failure | `BangumiNetworkError` |

### 5. Good / Base / Bad Cases

- Good:
  - `listCollections('alice', limit: 30, offset: 0, subjectTypes: [1, 2, 4, 6])`
  - page is parsed into `BangumiCollectionDto` rows for merge/import
- Base:
  - `listCollections('alice')`
  - service uses default page contract and still excludes unsupported media at
    the feature boundary
- Bad:
  - `listCollections('   ')`
  - passing unsupported subject type `3`
  - settings page calling the raw client directly and parsing JSON in UI

### 6. Tests Required

- Service tests:
  - invalid username fails before transport
  - negative offset is normalized
  - unsupported subject type filter fails before transport
  - embedded `subject` is preserved in parsed DTO rows
  - typed `BangumiApiException` subclasses escape, not `DioException`
- Integration-leaning tests:
  - page 1 + page 2 can be concatenated without losing `subjectId`
  - callers can fall back to `getSubject(id)` when `subject == null`

### 7. Wrong vs Correct

#### Wrong

```dart
Future<List<dynamic>> listCollections(String username) async {
  final response = await dio.get('/v0/users/$username/collections');
  return response.data as List<dynamic>;
}
```

## Scenario: WebDAV transport client for device-sync adapters

### 1. Scope / Trigger

- Trigger: phase 3 adds a reusable WebDAV storage adapter under
  `features/sync/data/`, while transport details stay in
  `shared/network/webdav_api_client.dart`.
- This is cross-layer because the same raw request contract flows through
  `WebDavApiClient` → `WebDavStorageAdapter` → `SyncStorageAdapter` consumers.

### 2. Signatures

```dart
class WebDavAuth {
  final String username;
  final String password;
}

class WebDavApiClient {
  Future<Response<String>> propfind(
    String path, {
    String depth = '1',
    String? body,
  });

  Future<Response<String>> getText(String path);
  Future<Response<String>> putText(
    String path, {
    required String content,
    String contentType = 'application/json; charset=utf-8',
  });
  Future<Response<String>> deleteResource(String path);
  Future<Response<String>> createCollection(String path);
}
```

### 3. Contracts

- `WebDavApiClient`
  - lives in `shared/network/`
  - owns `Dio` config, auth/header injection, and `DioException` →
    `WebDavApiException` mapping
  - returns raw `Response<String>` only; no repository imports and no merge logic
- headers / response mode
  - default `Accept` is `*/*`
  - default `responseType` is `ResponseType.plain`
  - `PROPFIND` adds:
    - method `PROPFIND`
    - header `Depth`
    - header `Content-Type: application/xml; charset=utf-8`
  - `MKCOL` uses method `MKCOL`
- auth
  - credentials come from `Future<WebDavAuth?> Function() authProvider`
  - client injects `Authorization: Basic <base64(username:password)>`
  - unauthenticated calls remove the authorization header instead of caching
    stale credentials in the client
- path normalization
  - client base url keeps a trailing slash
  - request paths stay relative and trim empty path segments
  - adapter/object layout stays under the sync contract:
    - `entities/<entityType>/<entityId>.json`
    - `tombstones/<entityType>/<entityId>.json`

### 4. Validation & Error Matrix

| Request / State | Expected Result | Error Surface |
|-----------------|-----------------|---------------|
| `propfind('entities', depth: 'infinity')` | raw XML string response | `WebDavApiException` subclasses |
| `createCollection('record-anywhere-sync/entities')` | sends `MKCOL` | `WebDavApiException` subclasses |
| missing credentials from `authProvider` | request proceeds without `Authorization` header | no client-side error |
| `401 / 403` | typed auth failure | `WebDavUnauthorizedError` |
| `404` | typed missing-resource failure | `WebDavNotFoundError` |
| `429` / `5xx` | typed server failure | `WebDavServerError` |
| timeout / socket failure | typed transport failure | `WebDavNetworkError` |

### 5. Good / Base / Bad Cases

- Good:
  - `propfind('record-anywhere-sync/entities', depth: 'infinity')`
  - `putText('entities/mediaItem/a.json', content: jsonText)`
  - `createCollection('record-anywhere-sync/entities/mediaItem')`
- Base:
  - `getText('entities/mediaItem/a.json')`
  - relative path is normalized and returned as plain text
- Bad:
  - widget/service calling `dio.request(method: 'PROPFIND', ...)` directly
  - adapter returning repository/domain objects from the network client
  - storing username/password directly on pages instead of using `authProvider`

### 6. Tests Required

- client / adapter tests:
  - `list/read/write/delete/tombstone` flow against mocked transport
  - `401` maps to auth failure
  - `404` maps to not-found failure
  - `5xx` maps to server failure
  - repeated directory creation tolerates server `405` / `409`
- mock assertion points:
  - custom WebDAV verbs (`MKCOL`, `PROPFIND`) are intercepted explicitly; do
    not rely on `http_mock_adapter` `RequestMethods.forName(...)` for unknown verbs
  - text-body reads use `text/plain` style mock headers when the expected result
    is raw string content, so tests do not accidentally JSON-encode the payload

### 7. Wrong vs Correct

#### Wrong

```dart
await dio.request(
  '/remote.php/dav/files/demo/entities',
  options: Options(method: 'PROPFIND'),
);
```

- transport leaks outside `shared/network/`
- no shared auth/header/error contract
- hard to reuse from the sync adapter

#### Correct

```dart
final response = await webDavApiClient.propfind(
  'record-anywhere-sync/entities',
  depth: 'infinity',
);

final xml = response.data ?? '';
```

- transport stays in the client layer
- auth and typed error mapping are centralized
- adapter can stay storage-only

- exposes transport objects
- loses DTO contract for merge/import
- lets invalid username and filter rules leak outward

#### Correct

```dart
Future<List<BangumiCollectionDto>> listCollections(
  String username, {
  int limit = 30,
  int offset = 0,
  List<int>? subjectTypes,
}) async {
  final normalizedUsername = username.trim();
  if (normalizedUsername.isEmpty) {
    throw ArgumentError.value(username, 'username');
  }

  final response = await _client.get<List<dynamic>>(
    '/v0/users/$normalizedUsername/collections',
    queryParameters: <String, dynamic>{
      'limit': limit <= 0 ? 30 : limit,
      'offset': offset < 0 ? 0 : offset,
      if (subjectTypes != null && subjectTypes.isNotEmpty)
        'subject_type': subjectTypes,
    },
  );

  return (response.data ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map((json) => BangumiCollectionDto.fromJson(Map<String, Object?>.from(json)))
      .toList(growable: false);
}
```

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

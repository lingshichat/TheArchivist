# Local-First Sync Contract

> Source-of-truth and sync-boundary rules for local writes and remote side effects.

---

## Overview

This project is local-first.

That means:

- the local database is the runtime source of truth
- remote sync is a side effect, not the primary write
- storage adapters and external platforms are integration boundaries, not
  product-state owners

This contract applies to Bangumi push sync now and to WebDAV / S3-compatible
device sync later.

---

## Scenario: Local write first, remote sync second

### 1. Scope / Trigger

Use this contract when changing any of:

- repository write paths
- sync metadata fields
- remote push hooks
- external mapping storage
- cross-device sync strategy
- conflict handling

### 2. Signatures

Current write-path signatures:

```dart
class MediaRepository {
  Future<String> createItem({
    required MediaType mediaType,
    required String title,
    String? subtitle,
    String? posterUrl,
    DateTime? releaseDate,
    String? overview,
    String? sourceIdsJson,
    int? runtimeMinutes,
    int? totalEpisodes,
    int? totalPages,
    double? estimatedPlayHours,
  });
}

class ActivityLogRepository {
  Future<void> appendEvent(
    String mediaItemId,
    ActivityEvent event, {
    Map<String, Object?> payload = const <String, Object?>{},
  });
}
```

Approved remote push boundary for Bangumi:

```dart
abstract class BangumiSyncService {
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  });
}
```

Minimum sync metadata for sync-capable entities:

```text
updatedAt
deletedAt
syncVersion
deviceId
lastSyncedAt
```

### 3. Contracts

#### Runtime truth

- Local DB writes happen first and complete independently
- Remote sync must not wrap the local write in an all-or-nothing workflow
- Remote failures never roll back local state

#### Mapping contract

- `sourceIdsJson` stores provider mappings as a JSON object
- Current Bangumi mapping shape:

```json
{"bangumi": "<subject_id>"}
```

- Future providers extend the same object with provider keys; do not create
  parallel source-id storage patterns

#### Sync-field ownership

- repositories stamp sync-capable fields
- pages must not stamp `updatedAt`, `syncVersion`, or `deviceId`
- phase-level fixes to device identity must happen through shared helpers, not
  one-off per-repository overrides

#### Adapter boundary

- Bangumi sync is an external platform integration
- WebDAV / S3-compatible sync is application-internal device sync
- These concerns stay separate even if both are "remote"
- Storage targets are transport/storage media; conflict policy stays in app code

### 4. Validation & Error Matrix

| Case | Expected behavior | Reject if |
|------|-------------------|-----------|
| Local create succeeds, user not bound to Bangumi | local record persists, remote push is a no-op | action is blocked on auth |
| Local status change succeeds, remote push times out | local state persists, light failure feedback only | local state is rolled back |
| Media item has no Bangumi mapping | skip Bangumi push | code guesses or fabricates a subject ID |
| Cross-device sync target has newer text field | apply conflict policy and keep conflict copy where required | remote overwrite silently drops local text |
| Adding a new provider mapping | extend `sourceIdsJson` object | add another unrelated mapping store |

### 5. Good / Base / Bad Cases

#### Good

- quick add writes local item, local entry, activity log, then triggers injected
  sync service
- remote adapters receive already-committed local state

#### Base

- phase 2 sync covers status and score only, with progress deferred explicitly

#### Bad

- remote API call is required before the local record is created
- repository write path depends on network availability
- Bangumi auth logic leaks into WP2 UI code

### 6. Tests Required

- Repository tests for create / update paths:
  - sync fields stamped by repository layer
  - `sourceIdsJson` persists expected provider mapping shape
- Sync-service tests:
  - unbound auth -> no-op
  - missing mapping -> no-op
  - remote failure -> local state unchanged
- Manual review:
  - local-first rule still holds across quick add and detail mutations
  - remote sync logic is injected behind service boundaries

### 7. Wrong vs Correct

#### Wrong

```dart
Future<void> addFromSearchResult(...) async {
  await bangumiApiService.updateCollection(...);
  await mediaRepository.createItem(...);
}
```

Why it is wrong:

- remote availability blocks the primary product action
- local-first guarantees are broken

#### Correct

```dart
final mediaItemId = await mediaRepository.createItem(...);
await activityLogRepository.appendEvent(mediaItemId, ActivityEvent.added);
await bangumiSyncService.pushCollection(
  mediaItemId: mediaItemId,
  status: status,
);
```

Why it is correct:

- local write is authoritative
- remote push is isolated and can fail independently
- future retry / queue logic can be added without changing the local write model

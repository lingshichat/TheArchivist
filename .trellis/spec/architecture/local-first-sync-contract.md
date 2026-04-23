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

This contract applies to Bangumi status/score pull+push sync now and to WebDAV /
S3-compatible device sync later.

---

## Scenario: Local write first, remote sync second

### 1. Scope / Trigger

Use this contract when changing any of:

- repository write paths
- sync metadata fields
- remote push hooks
- remote pull / import hooks
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

Approved remote pull boundary for Bangumi:

```dart
enum BangumiSyncTrigger { postConnect, startupRestore, manual }

class BangumiPullSummary {
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final int localWinsCount;
  final int failedCount;
}

abstract class BangumiPullService {
  Future<BangumiPullSummary> pullCollections({
    required String username,
    required BangumiSyncTrigger trigger,
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

Approved local queue/status signatures for device sync WP1:

```dart
class SyncQueueRepository {
  Future<List<SyncChangeCandidate>> listChangeCandidates({int limit = 100});
  Future<List<SyncQueueItem>> enqueuePendingChanges({int limit = 100});
  Future<SyncQueueItem> enqueue({...});
}

class SyncStatusRepository {
  Future<void> setStatus({
    required bool isRunning,
    required int pendingCount,
    String? lastErrorSummary,
    DateTime? lastCompletedAt,
    bool hasConflicts = false,
  });
}
```

Approved engine / adapter signatures for device sync WP2:

```dart
class SyncSummary {
  final int queuedCount;
  final int pushedCount;
  final int deletedCount;
  final int pullAppliedCount;
  final int pullSkippedCount;
  final int localWinsCount;
  final int failedCount;
  final String? lastErrorSummary;
}

abstract class SyncStorageAdapter {
  Future<List<SyncStorageRecordRef>> listRecords();
  Future<String> readText(String key);
  Future<void> writeText({required String key, required String content});
  Future<void> writeTombstone({
    required String key,
    required String content,
  });
  Future<void> delete(String key);
}

class SyncEngine {
  Future<SyncSummary> runSync({
    required SyncStorageAdapter adapter,
    int batchSize = 100,
  });
}

enum S3AddressingStyle { pathStyle, virtualHostedStyle }

class S3StorageAdapterConfig {
  final Uri endpoint;
  final String region;
  final String bucket;
  final String rootPrefix;
  final String accessKey;
  final String secretKey;
  final String? sessionToken;
  final S3AddressingStyle addressingStyle;
}
```

### 3. Contracts

#### Runtime truth

- Local DB writes happen first and complete independently
- Remote sync must not wrap the local write in an all-or-nothing workflow
- Remote failures never roll back local state
- Remote pull reconciles local state after auth/session checks; it does not
  replace the local DB as runtime truth

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
- sync services / coordinators may mark `lastSyncedAt` only after a successful
  pull-apply or push-commit path
- phase-level fixes to device identity must happen through shared helpers, not
  one-off per-repository overrides

#### Pull / merge contract

- Pull is allowed only for Bangumi-supported fields in the active phase
- Current Bangumi pull scope is:
  - `status`
  - `score`
- Current Bangumi pull explicitly excludes:
  - progress fields
  - notes / tags / shelves / favorite / review
  - remote delete / uncollect -> local delete behavior
- Pull matches rows by `sourceIdsJson.bangumi`
- When no local row exists for the Bangumi subject id:
  - create local item + local user entry
  - hydrate metadata from subject payload or follow-up `getSubject(...)`
- When a local row exists:
  - clean local row -> remote status/score may update local row
  - dirty local row -> local state wins; remote row must not overwrite it
- Current dirty-row minimum signal:
  - `updatedAt > lastSyncedAt`
  - or `lastSyncedAt == null` and the local row already contains a deliberate
    status / score
- `localWins` is a reconciliation outcome, not a fatal error
- Pull summary is a batch result; do not emit one blocking UI event per row

#### Adapter boundary

- Bangumi sync is an external platform integration
- WebDAV / S3-compatible sync is application-internal device sync
- These concerns stay separate even if both are "remote"
- Storage targets are transport/storage media; conflict policy stays in app code

#### Device queue / dirty-scan contract

- WP1 owns the shared local queue and minimal status snapshot for device sync
- `DeviceIdentityService` is the only approved source for stable current-device
  identity; repositories and queue code must not fabricate fallback `deviceId`
  strings
- dirty-scan uses the persisted sync metadata already stamped on local tables;
  it does not infer change state from UI memory
- current minimum dirty signal for cross-device sync is:
  - `lastSyncedAt == null`
  - `updatedAt > lastSyncedAt`
  - `deletedAt != null`
- `listChangeCandidates(...)` scans all sync-capable local tables and returns
  domain-neutral candidates; it must stay storage-agnostic and must not include
  WebDAV / S3 path logic
- `enqueuePendingChanges(...)` converts dirty candidates to queue rows:
  - non-deleted candidate -> `upsert`
  - soft-deleted candidate -> `delete`
- queue rows are the minimal replay contract:
  - `entityType`
  - `entityId`
  - `operation`
  - `lastAttemptedAt`
  - `retryCount`
  - `errorSummary`
  - `completedAt`
  - `deviceId`
- queue dedupe is per unfinished `(entityType, entityId, operation)` tuple
- minimal sync status is persisted separately from queue rows and currently
  tracks:
  - `isRunning`
  - `lastCompletedAt`
  - `lastErrorSummary`
  - `pendingCount`
  - `hasConflicts`
- settings or future sync UI may read this snapshot, but queue/status ownership
  stays in sync data layer

#### Device sync engine contract

- WP2 owns the reusable push / pull orchestration for cross-device sync
- push order is:
  - `enqueuePendingChanges(...)`
  - encode current local rows to `SyncEntityEnvelope`
  - write entity record or tombstone through `SyncStorageAdapter`
  - mark local rows synced only after remote write succeeds
  - mark queue row completed only after local sync stamp succeeds
- pull order is:
  - list remote records from adapter
  - sort by dependency-safe entity order before apply
  - decode remote text to `SyncEntityEnvelope`
  - evaluate merge in engine/codecs, not in adapter
  - call repository `applyRemoteSnapshot(...)` style entrypoints only when remote wins
- storage adapter stays transport-only:
  - no repository imports
  - no field-level merge
  - no UI state writes
- current S3-compatible adapter boundary is:
  - object APIs only: `ListObjectsV2`, `GetObject`, `PutObject`, `DeleteObject`
  - request signing uses SigV4 for service `s3`
  - adapter config carries explicit `endpoint`, `region`, `bucket`, `rootPrefix`,
    credentials, and `addressingStyle`
  - widgets / settings forms may collect these values later, but the adapter owns
    how they become host/path/query details
  - `listRecords()` hides remote pagination and must continue until the full
    result set is collected
  - current phase does not include bucket create/delete, multipart upload, or
    presigned URL workflows
- current remote object layout is:
  - entity record -> `entities/<entityType>/<entityId>.json`
  - tombstone -> `tombstones/<entityType>/<entityId>.json`
- current join-entity logical IDs are composed in engine/codec, not guessed by adapters:
  - tag link -> `<mediaItemId>::<tagId>`
  - shelf link -> `<mediaItemId>::<shelfListId>`
- current merge baseline is last-modified-wins for scalar / structural entities:
  - remote newer than local -> apply remote
  - local newer than remote -> `localWins`
  - same timestamp -> `skip`
- tombstone apply must preserve local soft-delete semantics; cross-device sync must not hard-delete business rows

### 4. Validation & Error Matrix

| Case | Expected behavior | Reject if |
|------|-------------------|-----------|
| Local create succeeds, user not bound to Bangumi | local record persists, remote push is a no-op | action is blocked on auth |
| Local status change succeeds, remote push times out | local state persists, light failure feedback only | local state is rolled back |
| Post-connect pull finds remote item not in local DB | create local item + entry from Bangumi mapping | require manual pre-creation |
| Startup pull finds local row dirty and remote row differs | keep local status/score, count `localWins` | remote pull blindly overwrites local row |
| Media item has no Bangumi mapping | skip Bangumi push | code guesses or fabricates a subject ID |
| Cross-device sync target has newer text field | apply conflict policy and keep conflict copy where required | remote overwrite silently drops local text |
| Adding a new provider mapping | extend `sourceIdsJson` object | add another unrelated mapping store |
| Dirty scan sees local row with `lastSyncedAt == null` | candidate is enqueued for device sync | row is silently skipped because no remote metadata exists yet |
| Dirty scan sees soft-deleted row | queue row uses `delete` operation | code hard-deletes row and loses replay signal |
| Same dirty row is scanned twice before completion | unfinished queue row is reused | duplicate unfinished queue rows are inserted |
| Settings page needs sync health summary | read persisted status snapshot | page queries queue tables directly and reconstructs state ad hoc |
| Device sync push writes remote entity successfully | local `lastSyncedAt` updates and queue row completes | queue row completes before remote write succeeds |
| Device sync pull sees older remote row | keep local row and count `localWins` or `skip` | stale remote row overwrites newer local state |
| Device sync pull sees tombstone | apply repository soft delete / detached state | engine hard-deletes runtime rows |
| WebDAV / S3 adapter is added later | adapter only implements storage contract | adapter invents a second engine-facing interface |
| S3 list response is truncated | adapter continues with continuation token(s) | adapter returns only the first 1000 objects |

### 5. Good / Base / Bad Cases

#### Good

- quick add writes local item, local entry, activity log, then triggers injected
  sync service
- remote adapters receive already-committed local state
- post-connect pull imports Bangumi rows that do not yet exist locally
- startup pull updates clean local rows but leaves dirty local rows untouched
- WP1 queue scan returns local dirty rows without knowing transport details
- queue enqueue maps soft delete to `delete` and normal mutations to `upsert`

#### Base

- phase 2 pull+push covers status and score only, with progress deferred explicitly
- minimal status snapshot reports queue-backed `pendingCount` without exposing a
  full retry center yet

#### Bad

- remote API call is required before the local record is created
- repository write path depends on network availability
- Bangumi auth logic leaks into WP2 UI code
- pull path overwrites local dirty rows without checking `lastSyncedAt`
- pull path treats remote uncollect as an instruction to delete the local row
- queue contract stores WebDAV/S3-specific paths instead of neutral entity keys
- feature pages infer dirty state themselves instead of reusing queue scan

### 6. Tests Required

- Repository tests for create / update paths:
  - sync fields stamped by repository layer
  - `sourceIdsJson` persists expected provider mapping shape
- Device-sync queue tests:
  - `DeviceIdentityService` persists and reuses stable current device id
  - dirty scan returns candidates for never-synced, updated-after-sync, and
    soft-deleted rows
  - repeated enqueue of the same unfinished candidate reuses one queue row
  - dirty enqueue maps soft delete to `delete`
  - status snapshot persists `isRunning`, `pendingCount`, and last summary data
- Sync-service tests:
  - unbound auth -> no-op
  - missing mapping -> no-op
  - remote failure -> local state unchanged
  - post-connect pull imports remote-only rows
  - dirty local row -> `localWins` and no overwrite
  - successful pull / push updates `lastSyncedAt` for affected local rows
- Manual review:
  - local-first rule still holds across quick add and detail mutations
  - remote pull / push logic is injected behind service boundaries

### 7. Wrong vs Correct

#### Wrong

```dart
Future<void> reconcileFromBangumi(RemoteRow row) async {
  await userEntryRepository.updateStatus(row.mediaItemId, row.status);
}
```

Why it is wrong:

- blindly applying remote state ignores local dirty checks
- local-first guarantees are broken for pull reconciliation

#### Correct

```dart
final isDirty =
    localEntry.lastSyncedAt == null ||
    localEntry.updatedAt.isAfter(localEntry.lastSyncedAt!);

if (isDirty) {
  summary.localWinsCount += 1;
  return;
}

await userEntryRepository.applyRemoteStatusAndScore(...);
await syncStampRepository.markLastSyncedAt(...);
```

Why it is correct:

- local state remains authoritative during conflict
- pull applies only when the local row is safe to update
- future retry / queue logic can still be added without changing the write model

#### Wrong

```dart
final queueRows = <Map<String, Object?>>[];
if (entity.deletedAt != null) {
  queueRows.add({'webdavPath': '/deleted/${entity.id}.json'});
}
```

#### Correct

```dart
final candidates = await syncQueueRepository.listChangeCandidates();
await syncQueueRepository.enqueuePendingChanges();
```

Why it is correct:

- queue contract stays transport-neutral
- dirty detection is centralized and reusable
- WebDAV / S3 adapters can consume the same queue later without redefinition

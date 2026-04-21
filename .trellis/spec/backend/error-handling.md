# Error Handling

> How errors are handled in this project.

---

## Overview

This is a Dart 3 Flutter project. Errors are classified by domain using
**sealed class hierarchies** and handled with exhaustive `switch` pattern matching.

The principle: **every layer catches what it understands and re-throws what it doesn't**.

---

## Error Architecture

```
External (dio, platform APIs, etc.)
  ↓ caught and mapped in network/infrastructure layer
Sealed Domain Exceptions (BangumiApiException, SyncException, ...)
  ↓ caught in controllers / services
Controller decides: retry, fallback, or propagate
  ↓ surfaced to UI
UI shows user-facing feedback (snackbar, empty state, inline message)
```

Rules:

- Network/infrastructure layers map raw errors to typed sealed exceptions
- Controllers catch typed exceptions and decide what to do
- UI catches only what it needs to display — never catches raw platform exceptions
- **Never** use bare `catch (e)` without a type in production code

---

## Sealed Exception Pattern

Define one sealed class per error domain:

```dart
sealed class BangumiApiException implements Exception {
  final String message;
  const BangumiApiException(this.message);
}

final class BangumiNetworkError extends BangumiApiException { ... }
final class BangumiUnauthorizedError extends BangumiApiException { ... }
// etc.
```

Rules:

- `sealed` ensures the compiler enforces exhaustive `switch` coverage
- Subclasses are `final` — no further extension
- Each subclass carries only the fields relevant to that error type
- Include a human-readable `message`; optional machine-readable `statusCode`

---

## Handling Patterns

### In controllers

```dart
try {
  await syncService.pushCollection(...);
} on BangumiUnauthorizedError {
  // Token expired — prompt re-auth
} on BangumiNetworkError {
  // Offline — local write kept, sync deferred
} on BangumiApiException {
  // Other API errors — light feedback
}
```

### In UI

```dart
// Only display-level handling
whenSink<AsyncValue<Result>>(
  data: (data) => showContent(data),
  error: (error, _) => showErrorSnackbar(error.toString()),
);
```

---

## Local-First Error Policy

This project is **local-first**. Rules for sync-related errors:

- Local writes **always** succeed immediately (database is local)
- Remote sync failures **never** roll back local state
- Sync errors produce light UI feedback (snackbar / status chip), not blocking dialogs
- Detailed error states (pending sync, retry) are deferred to Phase 4

## Scenario: Bangumi pull / push sync outcomes

### 1. Scope / Trigger

- Trigger: Bangumi sync now includes push after local mutation and pull during
  post-connect, startup restore, and manual `Sync now`.
- This needs code-spec depth because the same typed errors now drive different
  UI behavior depending on trigger and batch-vs-single-row context.

### 2. Signatures

```dart
enum BangumiSyncTrigger { postConnect, startupRestore, manual }

class BangumiPullSummary {
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final int localWinsCount;
  final int failedCount;
}

abstract class BangumiSyncService {
  Future<void> pushCollection({
    required String mediaItemId,
    UnifiedStatus? status,
    int? score,
  });
}

abstract class BangumiPullService {
  Future<BangumiPullSummary> pullCollections({
    required String username,
    required BangumiSyncTrigger trigger,
  });
}
```

### 3. Contracts

- Push path
  - success -> optional single light feedback
  - unauthorized -> clear auth/session, prompt reconnect with light feedback
  - network/server/not-found -> local write remains; no rollback
- Pull path
  - unauthorized -> clear auth/session; stop current batch
  - network/server failure during batch -> report summary-level failure, not one
    toast per row
  - row-level merge conflict where local dirty data wins -> count as
    `localWins`, not as fatal failure
- Trigger-specific UI contract
  - `startupRestore`: fail silently by default, update status state only
  - `postConnect`: may show one summary feedback
  - `manual`: may show one summary feedback
- Controllers and services may catch `BangumiApiException` subclasses, but
  widgets must not pattern-match raw transport exceptions

### 4. Validation & Error Matrix

| Context | Error / Outcome | Expected Behavior | Reject if |
|---------|------------------|------------------|-----------|
| push after local save | `BangumiUnauthorizedError` | local state kept, auth cleared, reconnect hint | local mutation is rolled back |
| pull during startup | `BangumiNetworkError` | no blocking dialog, keep last local state | startup route is blocked on sync |
| pull during manual sync | partial row merge failures | aggregate into summary / failed count | per-row toast storm |
| pull row with local dirty state | `localWins` outcome | keep local row, do not count as fatal error | remote row overwrites local dirty row |
| pull batch with zero import/update | success summary with zero counts | treated as exception |

### 5. Good / Base / Bad Cases

- Good:
  - manual sync ends with one summary message such as imported/updated counts
  - startup sync failure stays inside status state without blocking app use
- Base:
  - push failure shows one light message while local save remains successful
- Bad:
  - throwing generic `Exception('sync failed')` from pull service
  - treating `localWins` as an error that aborts the whole batch
  - showing stack traces or raw response bodies in sync feedback

### 6. Tests Required

- Push-path tests:
  - unauthorized clears auth state and preserves local row
  - network/server failures produce typed failure handling only
- Pull-path tests:
  - startup trigger failure stays silent
  - manual trigger failure produces one summary-level error
  - `localWins` increments summary without throwing
  - partial batch failures do not erase successful imports/updates

### 7. Wrong vs Correct

#### Wrong

```dart
try {
  await pullService.pullCollections(...);
} catch (e) {
  showDialog(context: context, builder: ...);
}
```

- raw catch loses typed error meaning
- sync behavior leaks into the widget
- blocking dialog breaks local-first expectations

#### Correct

```dart
try {
  final summary = await pullService.pullCollections(
    username: username,
    trigger: BangumiSyncTrigger.manual,
  );
  syncStatusController.complete(summary);
} on BangumiUnauthorizedError {
  await authController.invalidateSession();
  syncStatusController.failAuth();
} on BangumiApiException {
  syncStatusController.failTransient();
}
```

- typed errors stay inside controller/service boundaries
- local data remains usable
- batch sync produces status/summary state instead of blocking UI

---

## Forbidden Patterns

- Using `catch (e)` without specifying an error type
- Exposing `DioException`, `SocketException`, or other platform types outside the network layer
- Using error codes as integers (`if (e.code == 401)`) instead of typed exceptions
- Throwing generic `Exception('something went wrong')` — always use the domain sealed type
- Showing stack traces or raw error messages to users
- Using `try/catch` inside widget `build()` methods (handle in controllers/providers)

---

## Common Mistakes

- Catching at the wrong layer — network errors should be mapped before reaching controllers
- Forgetting to add a new sealed subclass to the `switch` — the compiler catches this
- Treating all errors the same way — unauthorized vs network vs not-found need different responses
- Adding retry logic in the wrong place — retry belongs in sync service, not in UI callbacks

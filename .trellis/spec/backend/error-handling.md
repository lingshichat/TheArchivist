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

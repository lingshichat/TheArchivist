# Logging Guidelines

> How logging is done in this project.

---

## Overview

This repository currently has **two logging surfaces**:

1. **Trellis Python scripts**
   - human-readable terminal status lines
   - shared helpers in `.trellis/scripts/common/log.py`
2. **Flutter app runtime**
   - no committed general-purpose logger yet
   - user-visible feedback and persisted `activity_logs` are preferred over
     ad hoc console output

The core rule is simple:

- CLI scripts may log operational status
- app runtime code must not scatter `print` / `debugPrint` through
  controllers, repositories, or widgets

---

## Scenario: Operator output and runtime diagnostics

### 1. Scope / Trigger

Use this spec when changing any of:

- `.trellis/scripts/**` command output
- future network / sync diagnostics in app runtime code
- `ActivityLogRepository.appendEvent(...)` usage for user-visible history

### 2. Signatures

Approved shared script logging helpers:

```python
def log_info(msg: str) -> None: ...
def log_success(msg: str) -> None: ...
def log_warn(msg: str) -> None: ...
def log_error(msg: str) -> None: ...
```

Approved persisted activity-log signature:

```dart
Future<void> appendEvent(
  String mediaItemId,
  ActivityEvent event, {
  Map<String, Object?> payload = const <String, Object?>{},
});
```

### 3. Contracts

#### Trellis script output

- Use `common/log.py` helpers for human-readable status updates
- Use plain `print(...)` only when the command's primary job is to emit final
  result text or machine-consumable output
- Keep reusable modules free of ad hoc colored-print logic; centralize it in
  `common/log.py`

#### Flutter app runtime

- Do not commit `print(...)` or `debugPrint(...)` in widgets, controllers,
  repositories, or providers
- Use typed exceptions, `AsyncValue`, and UI feedback (`LocalFeedback`,
  snackbars, status chips) for runtime visibility
- Use `ActivityLogRepository.appendEvent(...)` for user-visible lifecycle
  history, not as a substitute for transport debugging

#### Sensitive data

Never log:

- access tokens
- authorization headers
- private notes / reviews
- raw `payloadJson` blobs that contain user text
- full remote request/response bodies unless the spec is updated to define
  explicit redaction rules

### 4. Validation & Error Matrix

| Need | Approved surface | Reject if |
|------|------------------|-----------|
| CLI progress/status | `log_info/log_success/log_warn/log_error` | every script invents its own prefixes/colors |
| Final command result text | plain `print(...)` in entrypoint | helper modules mix result printing with business logic |
| User-visible lifecycle history | `ActivityLogRepository.appendEvent(...)` | console logs are used as product history |
| Runtime error feedback in app | typed errors + UI feedback | controller/repository prints token, payload, or stack trace |

### 5. Good / Base / Bad Cases

#### Good

- task-management scripts print final listings, but shared status messages use
  `common/log.py`
- product write paths record lifecycle events through `activity_logs`

#### Base

- short-lived local debugging uses temporary `debugPrint(...)`, then removes it
  before merge

#### Bad

- committed repository/controller code prints secrets or payloads
- a widget prints sync diagnostics instead of surfacing typed state
- a script helper hardcodes colors and prefixes instead of using `common/log.py`

### 6. Tests Required

- Search-based review before merge:
  - no committed `debugPrint(` in `lib/`
  - no committed token / authorization logging in `lib/` or `.trellis/scripts/`
- Manual review:
  - script output remains readable and intentional
  - user-visible history still comes from `activity_logs`, not console noise

### 7. Wrong vs Correct

#### Wrong

```dart
Future<void> pushCollection(...) async {
  print('token=$token body=$payload');
  await _client.post(...);
}
```

#### Correct

```dart
Future<void> pushCollection(...) async {
  try {
    await _client.post(...);
  } on BangumiApiException {
    rethrow;
  }
}
```

Why it is correct:

- error visibility stays in typed control flow
- secrets do not leak into logs
- UI and sync policy decide how to surface failure

---

## Log Levels

For Trellis scripts:

- `info`
  - normal progress and operator guidance
- `success`
  - completed state worth surfacing
- `warn`
  - non-blocking issue
- `error`
  - blocking failure

For Flutter app runtime:

- no shared committed logger yet
- if a shared logger is introduced later, update this spec first and keep the
  logger behind a single abstraction

---

## What to Log

- script lifecycle milestones
- task/worktree status transitions
- product activity history via `ActivityLogRepository`
- future sync diagnostics only after a centralized runtime logger is approved

---

## What NOT to Log

- tokens, secrets, auth headers
- private notes / reviews
- raw user-generated payload blobs
- duplicated low-value noise inside loops or hot paths

# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

For this repository, backend quality means:

- deterministic local-first write behavior
- clear ownership across controllers, repositories, services, and scripts
- typed errors and explicit boundaries
- reusable patterns that future phases can extend safely

These rules apply to Flutter non-UI code and relevant Trellis automation.

---

## Scenario: Mutation, sync, and integration code

### 1. Scope / Trigger

Use this spec when changing any of:

- controllers in `features/*/data/`
- repositories / DAOs / sync helpers
- transport / service integration code
- Trellis automation that coordinates non-trivial workflows

### 2. Signatures

Representative quality-critical signatures:

```dart
class AddEntryController {
  Future<String> create(AddEntryInput input);
}

class DetailActionsController {
  Future<void> applyQuickStatus(String mediaItemId, UnifiedStatus status);
  Future<void> saveChanges(String mediaItemId, DetailEntryUpdateInput input);
}

class MediaRepository {
  Future<String> createItem({...});
  Future<void> softDelete(String id);
}
```

### 3. Contracts

- controllers orchestrate multi-step mutations
- repositories own persistence details and sync stamping
- DAOs own query composition, not feature decisions
- services wrap transport details and emit typed domain results/errors
- pages read providers and call controllers; they do not choreograph storage
  writes directly
- shared provider registries stay cross-feature only

### 4. Validation & Error Matrix

| Change | Expected pattern | Reject if |
|--------|------------------|-----------|
| Multi-step write | controller orchestrates repo + activity-log side effects | button callback performs the full mutation flow inline |
| DB write stamp | repository owns timestamps/device/sync fields | widget or page stamps sync fields |
| Integration call | service/client layer hides transport details | page/controller parses raw `dio` response bodies |
| Shared constant / helper | single source of truth | same mapping or guard clause is copy-pasted into multiple files |
| New error path | typed exception or explicit `AsyncValue` state | generic `Exception(...)` or bare `catch (e)` |

---

## Forbidden Patterns

- Page or widget code calling DAO methods directly
- Page or widget code importing `dio`
- Multi-step writes implemented inline in UI callbacks
- Repositories depending on `BuildContext`, widget classes, or `WidgetRef`
- Generic `Exception('...')` in transport/sync code where a sealed domain error
  should exist
- Copying tag/shelf/name-normalization logic into multiple features instead of
  reusing repository helpers
- Using console logging as a substitute for typed state or persisted
  `activity_logs`

---

## Required Patterns

- Use controllers for write flows that touch multiple repositories or side
  effects
- Keep repository APIs domain-oriented and return `Future` / `Stream`, not UI
  types
- Keep integration-specific providers in the integration module, not in
  `shared/data/providers.dart`
- Normalize optional strings and repeated identifiers once, close to the write
  boundary
- Append lifecycle events through `ActivityLogRepository` when product history
  changes
- Keep local-first behavior explicit: local write first, remote side effects
  later

### Good / Base / Bad Cases

#### Good

- `DetailActionsController.saveChanges(...)` compares old/new state, performs
  repository mutations, and appends `ActivityLog` side effects
- `AddEntryController.create(...)` delegates storage details to repositories

#### Base

- a feature keeps a single-purpose helper private until a second consumer
  appears

#### Bad

- a page both parses remote JSON and writes local DB rows
- the same status-mapping rule exists in service, controller, and widget layers
- local mutation success depends on remote sync success

---

## Testing Requirements

Minimum:

- `flutter analyze lib test`
- `flutter test`

When changing repositories / controllers / services:

- add or update repository tests for create / update / soft-delete / round-trip
  behavior
- add controller tests when a mutation spans multiple repositories or remote
  side effects
- add mapping tests for enum / DTO translation when integration contracts
  change

Manual review points:

- local-first rule still holds
- side effects stay in controller / repository boundaries
- no forbidden imports leaked into `presentation/`

---

## Code Review Checklist

- Does the write path stay local-first?
- Are controllers coordinating mutations instead of pages?
- Are repositories the only owners of persistence details and sync stamps?
- Did integration-specific providers stay in the feature module?
- Are errors typed and handled at the right layer?
- Did the author avoid copy-pasting mappings or normalization rules?
- Were analyze/tests run, and are assertion points meaningful?

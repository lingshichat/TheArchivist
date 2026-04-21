# System Boundaries

> Ownership and dependency-direction rules for cross-layer work.

---

## Overview

This repository is a single Flutter application with local data,
external-integration modules, and Trellis automation scripts.

The goal of this code-spec is to keep shared contracts explicit:

- UI stays presentation-first
- non-UI logic stays in controllers / repositories / services
- transport concerns stay isolated
- durable architecture decisions do not drift into one-off task PRDs

---

## Scenario: Runtime module boundaries and dependency direction

### 1. Scope / Trigger

Use this contract when the change touches any of:

- 3+ runtime layers
- shell / router / shared widget ownership
- feature data modules
- shared repositories or providers
- external API integration boundaries
- reusable Trellis script helpers

### 2. Signatures

Representative runtime signatures to preserve:

```dart
final addEntryControllerProvider = Provider<AddEntryController>((ref) {
  return AddEntryController(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    shelfRepository: ref.watch(shelfRepositoryProvider),
    activityLogRepository: ref.watch(activityLogRepositoryProvider),
  );
});

class AddEntryController {
  Future<String> create(AddEntryInput input);
}

class MediaRepository {
  Stream<MediaItem> watchItem(String id);
  Future<String> createItem({...});
}

class BangumiApiService {
  Future<BangumiSearchResult> searchSubjects(String keyword, {...});
}
```

Representative automation boundary:

```text
.trellis/scripts/<entry>.py -> .trellis/scripts/common/*
```

### 3. Contracts

#### Runtime ownership

- `lib/app/`
  - bootstrap, router, shell chrome, route-scoped shell policy
- `lib/features/<feature>/presentation/`
  - page composition, local UI state, user interaction wiring
- `lib/features/<feature>/data/`
  - controllers, feature-local providers, integration DTOs/services/mappers
- `lib/shared/data/`
  - Drift tables, DAOs, repositories, cross-feature providers, local adapters
- `lib/shared/network/`
  - transport clients, interceptors, base config
- `lib/shared/widgets/`, `lib/shared/theme/`
  - reusable UI primitives and tokens

#### Dependency direction

```text
presentation/widget
  -> feature provider/controller
  -> repository/service
  -> DAO/client
  -> local DB / remote API
```

Rules:

- `presentation/` must not import DAOs or transport clients
- feature pages may read providers, but multi-step mutations go through
  controllers
- `shared/data/providers.dart` owns only cross-feature providers
- integration-specific providers stay in `features/<integration>/data/`
- shared widgets consume stable view data, not raw Drift rows
- shell geometry belongs in `app/shell/`, not scattered through page files

#### Automation ownership

- `.trellis/scripts/common/` owns shared Python helpers
- `.trellis/scripts/multi_agent/` owns worktree / agent orchestration
- hooks and entry scripts may format command output, but reusable logic belongs
  in `common/`

### 4. Validation & Error Matrix

| Change | Required placement | Reject if |
|--------|--------------------|-----------|
| New page-level mutation flow | feature controller + provider | page imports DAO directly |
| New external API client | `lib/shared/network/` + `features/<integration>/data/` | client lives in widget / page file |
| New integration provider | `features/<integration>/data/providers.dart` | provider added to `shared/data/providers.dart` |
| Shared DB-to-UI mapping | `lib/shared/data/local_view_adapters.dart` or feature adapter | shared widget reads Drift row directly |
| Shell width / header geometry change | `lib/app/shell/` | feature page redefines shell chrome |
| Reused Python helper | `.trellis/scripts/common/` | copy-pasted into multiple entry scripts |

### 5. Good / Base / Bad Cases

#### Good

- Bangumi transport lives in `shared/network/`
- Bangumi service / models / mapper / providers live in `features/bangumi/data/`
- UI reads `AsyncValue` or view data and triggers controllers only

#### Base

- A feature keeps temporary helper logic in its own `data/` directory
- Shared extraction happens once the same contract appears in 2+ places

#### Bad

- A page imports Drift DAOs
- `dio` leaks into widgets
- feature-specific providers pollute `shared/data/providers.dart`
- long-lived shell or sync decisions exist only inside one child task PRD

### 6. Tests Required

- `flutter analyze lib test`
- `flutter test`
- Search-based assertions when architecture changes:
  - no `package:dio/dio.dart` imports in `presentation/`
  - no DAO imports in `presentation/`
  - no shell constants duplicated in feature pages
- Manual review:
  - changed files sit in the right ownership directories
  - shared contracts are reflected in specs, not only in child task PRDs

### 7. Wrong vs Correct

#### Wrong

```dart
class AddEntryPage extends ConsumerWidget {
  Future<void> onPressed(WidgetRef ref) async {
    await ref.read(appDatabaseProvider).mediaDao.upsertItem(...);
  }
}
```

Why it is wrong:

- page code bypasses controller and repository boundaries
- write-side behavior, stamping, and side effects become inconsistent

#### Correct

```dart
final addEntryControllerProvider = Provider<AddEntryController>((ref) {
  return AddEntryController(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    shelfRepository: ref.watch(shelfRepositoryProvider),
    activityLogRepository: ref.watch(activityLogRepositoryProvider),
  );
});

await ref.read(addEntryControllerProvider).create(input);
```

Why it is correct:

- page stays presentation-first
- repository and logging side effects stay centralized
- future sync hooks can be added without rewriting the page layer
